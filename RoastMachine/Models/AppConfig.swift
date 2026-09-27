//
//  AppConfig.swift
//  RoastMachine
//
//  The app ships no API keys. OpenAI and ElevenLabs are called by the
//  `roastmachine` Edge Function in the shared Second-Brain Supabase project.
//

import Foundation

enum AppConfig {
    static let backendURL = URL(string: "https://jqvohqudydzolyqfijrb.supabase.co/functions/v1/roastmachine")!
    static let privacyPolicyURL = URL(string: "https://pbakerx.github.io/roast_machine/privacy.html")!
}
