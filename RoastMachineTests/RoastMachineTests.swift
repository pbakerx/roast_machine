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

    func testEveryComedianHasABundledPreview() {
        let bundle = Bundle(for: StoreManager.self)
        for mode in RoastMode.all {
            for flavor in ["roast", "hype"] {
                XCTAssertNotNil(bundle.url(forResource: "preview_\(mode.id)_\(flavor)", withExtension: "mp3"),
                                "\(mode.id) \(flavor)")
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
