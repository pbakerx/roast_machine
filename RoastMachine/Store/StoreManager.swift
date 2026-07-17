//
//  StoreManager.swift
//  RoastMachine
//
//  StoreKit 2 wrapper for the freemium model:
//    - Core (Classic Roast + Nature Documentary) is free.
//    - "All Modes" and "Premium Voices" are small non-consumable unlocks.
//    - Optional consumable roast-credit packs.
//

import StoreKit

@MainActor
final class StoreManager: ObservableObject {

    // Product identifiers — must match Subscriptions.storekit / App Store Connect.
    enum ProductID {
        static let allModes = "AechTech.RoastMachine.allmodes"
        static let voices   = "AechTech.RoastMachine.voices"
        static let credits  = "AechTech.RoastMachine.credits20"

        static let all: [String] = [allModes, voices, credits]
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var ownedProductIDs: Set<String> = []
    @Published var purchaseInFlight = false
    @Published var isLoadingProducts = false
    @Published var didAttemptLoad = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        // Listen for transactions that arrive outside an explicit purchase (e.g. restores).
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Entitlement helpers

    /// DEV ONLY: unlock every premium mode + voice without a purchase.
    /// Set to `false` before shipping to TestFlight / the App Store.
    static let devUnlockEverything = true

    var hasAllModes: Bool {
        Self.devUnlockEverything || ownedProductIDs.contains(ProductID.allModes)
    }
    var hasPremiumVoices: Bool {
        Self.devUnlockEverything || ownedProductIDs.contains(ProductID.voices)
    }

    /// Whether a given mode is playable right now.
    func isUnlocked(_ mode: RoastMode) -> Bool {
        mode.isPremium ? hasAllModes : true
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: - Loading

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false; didAttemptLoad = true }
        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = loaded.sorted { $0.price < $1.price }
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
