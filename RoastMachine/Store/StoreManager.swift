//
//  StoreManager.swift
//  RoastMachine
//
//  The Box Office. Every install gets one free roast and one free hype; after
//  that each show costs a ticket. Tickets are consumable StoreKit packs, and the
//  balance lives on the server (so it can't be edited on-device, survives
//  reinstalls, and every purchase is verified against Apple's signature before
//  it's credited).
//

import StoreKit

@MainActor
final class StoreManager: ObservableObject {

    // Must match App Store Connect, Subscriptions.storekit and the server's PRODUCTS.
    enum ProductID {
        static let tickets8  = "AechTech.RoastMachine.tickets8"
        static let tickets20 = "AechTech.RoastMachine.tickets20"
        static let tickets60 = "AechTech.RoastMachine.tickets60"
        static let all = [tickets8, tickets20, tickets60]
    }

    struct Pack: Identifiable {
        let id: String
        let name: String
        let tickets: Int
        let badge: String?
    }

    static let packs: [Pack] = [
        Pack(id: ProductID.tickets8,  name: "Top-Up",      tickets: 8,  badge: nil),
        Pack(id: ProductID.tickets20, name: "Opening Act", tickets: 20, badge: "MOST POPULAR"),
        Pack(id: ProductID.tickets60, name: "Headliner",   tickets: 60, badge: "BEST VALUE"),
    ]

    @Published private(set) var products: [Product] = []
    /// Nil until the first server fetch lands.
    @Published private(set) var wallet: Wallet? {
        didSet { resetSoldOutStrikesIfStocked() }
    }
    @Published var purchaseInFlight = false
    @Published var isLoadingProducts = false
    @Published var didAttemptLoad = false
    @Published var lastError: String?

    private let backend: Backend
    private var updatesTask: Task<Void, Never>?

    init(backend: Backend = .shared) {
        self.backend = backend
        // Purchases that complete outside an explicit buy (Ask to Buy, interrupted
        // purchases) arrive here.
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.process(result)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    /// Called once at launch.
    func start() async {
#if DEBUG && targetEnvironment(simulator)
        // Test rig: `SIMCTL_CHILD_RM_DEMO_SOLDOUT=1` starts with an empty wallet
        // so the sold-out roasts can be heard without touching the server.
        if ProcessInfo.processInfo.environment["RM_DEMO_SOLDOUT"] == "1" {
            wallet = Wallet(tickets: 0, freeRoast: false, freeHype: false)
            await loadProducts()
            return
        }
#endif
        await loadProducts()
        await refreshWallet()
        // Credit anything bought but not yet acknowledged (e.g. the app was killed mid-purchase).
        for await result in Transaction.unfinished {
            await process(result)
        }
    }

    // MARK: - Wallet

    var tickets: Int { wallet?.tickets ?? 0 }

    func freeRunRemaining(for flavor: RoastFlavor) -> Bool {
        wallet?.freeRunRemaining(for: flavor) ?? false
    }

    /// Whether the shutter should fire. Optimistic until the wallet loads —
    /// the server has the final say either way.
    func canRun(_ flavor: RoastFlavor) -> Bool {
        if Self.demoUnlock { return true }
        return wallet?.canRun(flavor) ?? true
    }

    var showsTicketBanner: Bool { !Self.demoUnlock && wallet != nil }

    // MARK: - Sold out

    private static let soldOutStrikesKey = "rm.soldOutStrikes"

    /// Counts shutter presses with no tickets: 1 nudges, 2 stings, 3 (and
    /// every try after) is the savage one. Starts over once tickets are bought.
    func nextSoldOutStrike() -> Int {
        let strike = min(UserDefaults.standard.integer(forKey: Self.soldOutStrikesKey) + 1, 3)
        UserDefaults.standard.set(strike, forKey: Self.soldOutStrikesKey)
        return strike
    }

    private func resetSoldOutStrikesIfStocked() {
        if (wallet?.tickets ?? 0) > 0 {
            UserDefaults.standard.removeObject(forKey: Self.soldOutStrikesKey)
        }
    }

    func apply(_ wallet: Wallet?) {
        if let wallet { self.wallet = wallet }
    }

    func refreshWallet() async {
        do { wallet = try await backend.wallet() } catch { /* keep last known */ }
    }

#if DEBUG && targetEnvironment(simulator)
    /// Screenshot rig: `SIMCTL_CHILD_RM_DEMO_UNLOCK=1` hides the ticket UI.
    private static let demoUnlock = ProcessInfo.processInfo.environment["RM_DEMO_UNLOCK"] == "1"
#else
    private static let demoUnlock = false
#endif

    // MARK: - Products

    func product(for pack: Pack) -> Product? {
        products.first { $0.id == pack.id }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false; didAttemptLoad = true }
        do {
            products = try await Product.products(for: ProductID.all)
            if products.isEmpty {
                lastError = "The Box Office is closed right now. Try again in a moment."
            }
        } catch {
            lastError = "Couldn't reach the App Store: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase(options: [.appAccountToken(backend.walletID)])
            if case .success(let verification) = result {
                await process(verification)
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    /// Hands a signed transaction to the server, which verifies Apple's
    /// signature and credits the tickets exactly once. Only then is it finished;
    /// a failed credit stays unfinished and is retried at next launch.
    private func process(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        guard transaction.productType == .consumable, ProductID.all.contains(transaction.productID) else {
            await transaction.finish()
            return
        }
        do {
            let credit = try await backend.credit(jws: result.jwsRepresentation)
            wallet = credit.wallet
            await transaction.finish()
        } catch {
            lastError = "Your purchase went through, but the tickets are still on their way. They'll appear next time you open the app."
        }
    }
}
