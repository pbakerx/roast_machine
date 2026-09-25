//
//  AppConfig.swift
//  RoastMachine
//
//  Reads API keys that are injected from Secrets.xcconfig via RoastMachine-Info.plist.
//  Same pattern used in the AssistAI project.
//

import Foundation

enum AppConfig {
    static var openAIKey: String {
        value(for: "OPENAI_API_KEY")
    }

    static var elevenLabsKey: String {
        value(for: "ELEVENLABS_API_KEY")
    }

    static let privacyPolicyURL = URL(string: "https://pbakerx.github.io/roast_machine/privacy.html")!

    static var hasOpenAIKey: Bool { !openAIKey.isEmpty }
    static var hasElevenLabsKey: Bool { !elevenLabsKey.isEmpty }

    private static func value(for key: String) -> String {
        guard let raw = Bundle.main.infoDictionary?[key] as? String else { return "" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ignore an unfilled placeholder so the app can show a friendly setup message.
        if trimmed.hasPrefix("PASTE_") { return "" }
        return trimmed
    }
}
