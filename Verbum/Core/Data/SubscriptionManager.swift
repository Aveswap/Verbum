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
    /// Set true once when entitlement goes Pro → not-Pro (expiry/revocation), so the UI can
    /// show a soft "your subscription has ended" banner. UI clears it after presenting.
    @Published var subscriptionEnded: Bool = false

    /// Persisted across launches so a lapse that happened while the app was closed is also
    /// surfaced on next open (not just mid-session expiry).
    private static let wasProKey = "verbum.wasPro"

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
                switch verification {
                case .verified(let tx):
                    await tx.finish()
                    await refreshEntitlements()
                case .unverified(let tx, _):
                    // Don't grant entitlement, but still finish so the unverified
                    // transaction clears the queue instead of resurfacing repeatedly.
                    await tx.finish()
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
        // Surface a Pro → not-Pro transition exactly once. Compare against the persisted
        // prior state so a lapse that happened while the app was closed is also caught.
        let wasPro = UserDefaults.standard.bool(forKey: Self.wasProKey)
        if wasPro && !active {
            subscriptionEnded = true
        }
        UserDefaults.standard.set(active, forKey: Self.wasProKey)
        isPro = active
    }

    // MARK: - Transaction listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let tx):
                await tx.finish()
                await refreshEntitlements()
            case .unverified(let tx, _):
                // Finish unverified updates too so they don't keep replaying in the queue.
                await tx.finish()
            }
        }
    }
}
