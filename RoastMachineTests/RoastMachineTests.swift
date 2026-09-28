//
//  RoastMachineTests.swift
//  RoastMachineTests
//
//  Client-side logic: the comedian catalog and the wallet's gating rules.
//  Prompt assembly and ticket accounting live on the server
//  (supabase/functions/_shared/apple_test.ts, app_roastmachine.spend_show).
//

import XCTest
@testable import RoastMachine

final class CatalogTests: XCTestCase {

    /// Must match PERSONAS in supabase/functions/_shared/personas.ts.
    private let serverModeIDs: Set<String> = [
        "classic", "nature", "ramsay", "mom", "shakespeare", "disstrack", "beautiful",
        "fortune", "drill", "linkedin", "conspiracy", "pickup", "datingbio", "pet",
    ]

    func testCatalogMatchesServerPersonas() {
        XCTAssertEqual(Set(RoastMode.all.map(\.id)), serverModeIDs)
        XCTAssertEqual(RoastMode.all.count, serverModeIDs.count)
        XCTAssertEqual(RoastMode.all.first?.id, "classic")
    }

    /// Must match VOICE_CATALOG in supabase/functions/_shared/personas.ts.
    private let serverVoiceKeys: Set<String> = [
        "larry", "ace", "ziggy", "georgee", "minnie", "tom", "lizzie", "ranger",
    ]

    func testVoicesMatchServerCatalog() {
        XCTAssertEqual(Set(Voice.all.map(\.id)), serverVoiceKeys)
        XCTAssertEqual(Voice.all.count, serverVoiceKeys.count)
        XCTAssertEqual(Voice.withID(Voice.defaultRoast).id, "larry")
        XCTAssertEqual(Voice.withID(Voice.defaultHype).id, "ace")
        XCTAssertEqual(Voice.withID("retired-voice").id, Voice.all[0].id)
    }

    func testEveryVoiceHasBundledSamples() {
        let bundle = Bundle(for: StoreManager.self)
        for voice in Voice.all {
            for flavor in ["roast", "hype"] {
                XCTAssertNotNil(bundle.url(forResource: "voice_\(voice.id)_\(flavor)", withExtension: "mp3"),
                                "\(voice.id) \(flavor)")
            }
        }
    }

    func testEveryVoiceHasSoldOutRoasts() {
        let bundle = Bundle(for: StoreManager.self)
        for voice in Voice.all {
            for strike in 1...3 {
                XCTAssertNotNil(bundle.url(forResource: "soldout_\(voice.id)_\(strike)", withExtension: "mp3"),
                                "\(voice.id) strike \(strike)")
            }
        }
    }

    func testTicketPacksMatchServerProducts() {
        XCTAssertEqual(StoreManager.packs.map(\.tickets), [8, 20, 60])
        XCTAssertEqual(Set(StoreManager.packs.map(\.id)), Set(StoreManager.ProductID.all))
    }
}

final class WalletTests: XCTestCase {

    func testFreshWalletRunsBothFlavorsFree() {
        let w = Wallet(tickets: 0, freeRoast: true, freeHype: true)
        XCTAssertTrue(w.canRun(.roast))
        XCTAssertTrue(w.canRun(.compliment))
    }

    func testFreeRunsAreIndependent() {
        let w = Wallet(tickets: 0, freeRoast: false, freeHype: true)
        XCTAssertFalse(w.canRun(.roast))
        XCTAssertTrue(w.canRun(.compliment))
    }

    func testTicketsCoverEitherFlavor() {
        let w = Wallet(tickets: 1, freeRoast: false, freeHype: false)
        XCTAssertTrue(w.canRun(.roast))
        XCTAssertTrue(w.canRun(.compliment))
        XCTAssertFalse(Wallet(tickets: 0, freeRoast: false, freeHype: false).canRun(.roast))
    }

    func testDecodesServerWallet() throws {
        let json = #"{"tickets":7,"free_roast":false,"free_hype":true}"#.data(using: .utf8)!
        let w = try JSONDecoder().decode(Wallet.self, from: json)
        XCTAssertEqual(w, Wallet(tickets: 7, freeRoast: false, freeHype: true))
    }
}

@MainActor
final class SoldOutTests: XCTestCase {

    override func setUp() {
        UserDefaults.standard.removeObject(forKey: "rm.soldOutStrikes")
    }

    func testStrikesEscalateThenHoldAtThree() {
        let store = StoreManager()
        XCTAssertEqual((1...5).map { _ in store.nextSoldOutStrike() }, [1, 2, 3, 3, 3])
    }

    func testBuyingTicketsStartsTheCountOver() {
        let store = StoreManager()
        _ = store.nextSoldOutStrike()
        _ = store.nextSoldOutStrike()
        store.apply(Wallet(tickets: 0, freeRoast: false, freeHype: false))
        XCTAssertEqual(store.nextSoldOutStrike(), 3, "an empty wallet doesn't reset")
        store.apply(Wallet(tickets: 8, freeRoast: false, freeHype: false))
        XCTAssertEqual(store.nextSoldOutStrike(), 1)
    }
}
