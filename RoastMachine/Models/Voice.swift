//
//  Voice.swift
//  RoastMachine
//
//  The voices a player can pick from, one for roasts and one for hype. The
//  ElevenLabs ids live on the server (VOICE_CATALOG in personas.ts); the app
//  only ever sends the `id` key, which the server whitelists.
//

import Foundation

struct Voice: Identifiable, Hashable {
    let id: String
    let name: String
    let vibe: String
    let emoji: String

    static let all: [Voice] = [
        Voice(id: "larry",   name: "Larry",         vibe: "Big hype-man energy", emoji: "🎙️"),
        Voice(id: "ace",     name: "ACE the Bee",   vibe: "Buzzing with joy",    emoji: "🐝"),
        Voice(id: "ziggy",   name: "Ziggy",         vibe: "Cute little Aussie",  emoji: "🦘"),
        Voice(id: "georgee", name: "Georgee",       vibe: "Cartoon kid",         emoji: "🎈"),
        Voice(id: "minnie",  name: "Minnie",        vibe: "Squeaky & sweet",     emoji: "🧁"),
        Voice(id: "tom",     name: "Captain Tom",   vibe: "Salty pirate",        emoji: "🏴‍☠️"),
        Voice(id: "lizzie",  name: "Lizzie",        vibe: "Cheeky Cockney",      emoji: "☕"),
        Voice(id: "ranger",  name: "Desert Ranger", vibe: "Gravelly cowboy",     emoji: "🤠"),
    ]

    static let defaultRoast = "larry"
    static let defaultHype = "ace"

    static func withID(_ id: String) -> Voice {
        all.first { $0.id == id } ?? all[0]
    }
}
