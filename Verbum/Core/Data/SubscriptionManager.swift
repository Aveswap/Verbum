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
    /// True when the last loadProducts() returned no products (network/StoreKit/ASC config
    /// problem). The paywall shows a retry affordance instead of fake hardcoded-price rows.
    @Published private(set) var loadFailed: Bool = false
    /// Flips true once the first entitlement check has actually completed. Until then the UI
    /// must not show the "subscription ended" banner — on a cold launch / reinstall
    /// `Transaction.currentEntitlements` can momentarily read empty for a still-active sub.
    @Published private(set) var hasCheckedEntitlements: Bool = false
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
        let fetched = (try? await Product.products(for: Self.allIDs)) ?? []
        products = fetched.sorted { productOrder($0) < productOrder($1) }
        loadFailed = products.isEmpty
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
                case .unverified(_, let error):
                    // Do NOT grant entitlement AND do NOT finish: a transient verification
                    // failure (device clock skew, JWS hiccup) must be allowed to re-deliver via
                    // Transaction.updates once it verifies — finishing here would permanently
                    // strip a paying user of access. (Apple: only finish verified transactions.)
                    purchaseError = "Purchase could not be verified — it will retry automatically. (\(error.localizedDescription))"
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
        // Surface a Pro → not-Pro transition once — but only when StoreKit was actually
        // reachable (products loaded). On a cold launch with no connectivity, an empty
        // currentEntitlements read is meaningless and must not flash a false "ended" banner;
        // when products DID load, an empty read genuinely means the sub lapsed (incl. while
        // the app was closed). loadProducts() runs before this in init, so loadFailed is set.
        if wasPro && !active && !loadFailed {
            subscriptionEnded = true
        }
        // Persist the lapse only once we trust the read, so a flaky-network launch doesn't
        // wipe the "was Pro" flag and then miss the real lapse on the next good launch.
        if active || !loadFailed {
            UserDefaults.standard.set(active, forKey: Self.wasProKey)
        }
        isPro = active
        hasCheckedEntitlements = true
    }

    // MARK: - Transaction listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let tx):
                await tx.finish()
                await refreshEntitlements()
            case .unverified:
                // Leave unverified transactions in the queue so StoreKit re-delivers them once
                // verification succeeds. Finishing here would drop a genuine purchase.
                break
            }
        }
    }
}
