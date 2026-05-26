import StoreKit
import Combine

/// Single source of truth for premium status. Uses StoreKit 2 (iOS 15+).
/// Inject as @EnvironmentObject from VerbumApp.
@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Product IDs (must match App Store Connect)
    static let monthlyID  = "pro_monthly"
    static let yearlyID   = "pro_yearly"
    static let lifetimeID = "pro_lifetime"
    static let allIDs     = [monthlyID, yearlyID, lifetimeID]

    // MARK: - State
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var purchaseError: String? = nil

    private var updatesTask: Task<Void, Never>?
    private var initTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await listenForTransactions() }
        initTask = Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
        initTask?.cancel()
    }

    // MARK: - Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        products = (try? await Product.products(for: Self.allIDs)) ?? []
        products.sort { productOrder($0) < productOrder($1) }
    }

    private func productOrder(_ p: Product) -> Int {
        switch p.id {
        case Self.monthlyID:  return 0
        case Self.yearlyID:   return 1
        case Self.lifetimeID: return 2
        default:              return 3
        }
    }

    var monthlyProduct: Product?  { products.first { $0.id == Self.monthlyID } }
    var yearlyProduct: Product?   { products.first { $0.id == Self.yearlyID } }
    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeID } }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    await refreshEntitlements()
                } else {
                    purchaseError = "Purchase could not be verified."
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               Self.allIDs.contains(tx.productID),
               tx.revocationDate == nil {
                active = true
                break
            }
        }
        isPro = active
    }

    // MARK: - Transaction listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let tx) = result {
                await tx.finish()
                await refreshEntitlements()
            }
        }
    }
}
