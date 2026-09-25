//
//  RoastMachineTests.swift
//  RoastMachineTests
//
//  Pure-logic coverage for the pieces App Review will exercise hardest:
//  prompt assembly (roast vs hype) and paywall gating.
//

import XCTest
@testable import RoastMachine

final class PromptAssemblyTests: XCTestCase {

    private var classic: RoastMode { RoastMode.classic }

    func testDefaultFlavorIsRoast() {
        let prompt = classic.fullPrompt()
        XCTAssertTrue(prompt.hasPrefix(RoastMode.sharedPreamble))
        XCTAssertTrue(prompt.contains("PERSONA:"))
        XCTAssertTrue(prompt.hasSuffix(classic.personaPrompt))
    }

    func testComplimentFlavorSwapsPreamble() {
        let prompt = classic.fullPrompt(flavor: .compliment)
        XCTAssertTrue(prompt.hasPrefix(RoastMode.complimentPreamble))
        XCTAssertFalse(prompt.contains(RoastMode.sharedPreamble))
        // Persona still rides along so the character survives the flip.
        XCTAssertTrue(prompt.hasSuffix(classic.personaPrompt))
    }

    func testComplimentPreambleOverridesRoastInstructions() {
        let preamble = RoastMode.complimentPreamble
        XCTAssertTrue(preamble.contains("compliment"))
        XCTAssertTrue(preamble.contains("ignore that part"))
    }

    func testEveryModeHasDistinctPersonaAndVoice() {
        let modes = RoastMode.all
        XCTAssertEqual(modes.count, 14)
        XCTAssertEqual(Set(modes.map(\.id)).count, modes.count)
        XCTAssertFalse(modes.contains { $0.personaPrompt.isEmpty || $0.voiceID.isEmpty })
    }

    func testClassicHeadlinesTheDial() {
        XCTAssertEqual(RoastMode.all.first?.id, "classic")
        XCTAssertEqual(RoastMode.classic.id, "classic")
    }
}

@MainActor
final class StoreGatingTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "RoastMachineTests.store")
        defaults.removePersistentDomain(forName: "RoastMachineTests.store")
    }

    func testDevUnlockIsOffForRelease() {
        XCTAssertFalse(StoreManager.devUnlockEverything,
                       "devUnlockEverything must be false for release")
    }

    func testFreshInstallGetsOneRoastAndOneHype() {
        let store = StoreManager(defaults: defaults)
        XCTAssertFalse(store.hasEverything)
        XCTAssertTrue(store.canRun(.roast))
        XCTAssertTrue(store.canRun(.compliment))
    }

    func testFreeRunsAreIndependentAndSingleUse() {
        let store = StoreManager(defaults: defaults)

        store.consumeFreeRun(.roast)
        XCTAssertFalse(store.canRun(.roast))
        XCTAssertTrue(store.canRun(.compliment), "burning the roast must not touch the hype")

        store.consumeFreeRun(.compliment)
        XCTAssertFalse(store.canRun(.compliment))
    }

    func testFreeRunsPersistAcrossRelaunch() {
        StoreManager(defaults: defaults).consumeFreeRun(.roast)

        let relaunched = StoreManager(defaults: defaults)
        XCTAssertFalse(relaunched.canRun(.roast))
        XCTAssertTrue(relaunched.canRun(.compliment))
    }
}
