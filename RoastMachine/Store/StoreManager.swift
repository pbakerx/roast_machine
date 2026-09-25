//
//  StoreManager.swift
//  RoastMachine
//
//  StoreKit 2 wrapper for the simplest possible model:
//    - Every install gets ONE free roast and ONE free hype (any comedian).
//    - One $2.99 non-consumable ("Everything") unlocks unlimited runs of
//      every comedian, forever. No subscriptions, no credit packs.
//

import StoreKit

@MainActor
final class StoreManager: ObservableObject {

    // Product identifier — must match Subscriptions.storekit / App Store Connect.
    enum ProductID {
        static let everything = "AechTech.RoastMachine.allmodes"
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var ownedProductIDs: Set<String> = []
    @Published var purchaseInFlight = false
    @Published var isLoadingProducts = false
    @Published var didAttemptLoad = false
    @Published var lastError: String?

    /// The two free tastes. Persisted so they survive relaunches.
    @Published private(set) var freeRoastUsed: Bool
    @Published private(set) var freeHypeUsed: Bool

    private let defaults: UserDefaults
    private var updatesTask: Task<Void, Never>?

    private static let freeRoastKey = "rm.freeRoastUsed"
    private static let freeHypeKey = "rm.freeHypeUsed"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        freeRoastUsed = defaults.bool(forKey: Self.freeRoastKey)
        freeHypeUsed = defaults.bool(forKey: Self.freeHypeKey)

        // Listen for transactions that arrive outside an explicit purchase (e.g. restores).
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Entitlement helpers

    /// DEV ONLY: unlock everything without a purchase.
    /// Keep `false` so the real paywall runs everywhere; flip to `true`
    /// only for local UI work that shouldn't touch the store.
    static let devUnlockEverything = false

    var hasEverything: Bool {
        Self.devUnlockEverything || Self.demoUnlock
            || ownedProductIDs.contains(ProductID.everything)
    }

#if DEBUG && targetEnvironment(simulator)
    /// Screenshot rig: `SIMCTL_CHILD_RM_DEMO_UNLOCK=1 xcrun simctl launch …`
    /// shows the paid experience without touching the store.
    private static let demoUnlock = ProcessInfo.processInfo.environment["RM_DEMO_UNLOCK"] == "1"
#else
    private static let demoUnlock = false
#endif

    var everythingProduct: Product? {
        products.first { $0.id == ProductID.everything }
    }

    /// Whether the free taste for this flavor is still on the table.
    func freeRunRemaining(for flavor: RoastFlavor) -> Bool {
        switch flavor {
        case .roast:      return !freeRoastUsed
        case .compliment: return !freeHypeUsed
        }
    }

    /// Whether the shutter should fire for this flavor right now.
    func canRun(_ flavor: RoastFlavor) -> Bool {
        hasEverything || freeRunRemaining(for: flavor)
    }

    /// The free taste has been fired — burn it. No-op once everything is owned.
    func consumeFreeRun(_ flavor: RoastFlavor) {
        guard !hasEverything else { return }
        switch flavor {
        case .roast:
            freeRoastUsed = true
            defaults.set(true, forKey: Self.freeRoastKey)
        case .compliment:
            freeHypeUsed = true
            defaults.set(true, forKey: Self.freeHypeKey)
        }
    }

    // MARK: - Loading

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false; didAttemptLoad = true }
        do {
            products = try await Product.products(for: [ProductID.everything])
            if products.isEmpty {
                lastError = "No products came back. In Xcode: Edit Scheme ▸ Run ▸ Options ▸ StoreKit Configuration ▸ select Subscriptions.storekit."
            }
        } catch {
            lastError = "Couldn't load the store: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        ownedProductIDs = owned
    }

    // MARK: - Purchase / restore

    func purchase(_ product: Product) async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(transactionResult: verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Private

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = transactionResult else { return }
        if transaction.productType != .consumable {
            ownedProductIDs.insert(transaction.productID)
        }
        await transaction.finish()
    }
}
