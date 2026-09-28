//
//  RoastMode.swift
//  RoastMachine
//
//  The comedians as the app presents them. Their prompts and ElevenLabs voices
//  live on the server (supabase/functions/_shared/personas.ts), keyed by `id` —
//  the app sends only a mode id, never a prompt.
//

import SwiftUI

/// Which way the machine is pointed: burn them or build them up.
/// Free-tier feature — every mode can deliver either.
enum RoastFlavor: String {
    case roast
    case compliment
}

struct RoastMode: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    /// The name to show for a run. A few comedians have burn-y names that read
    /// wrong on a HYPE show, so they get a hype name; the rest work both ways.
    func title(for flavor: RoastFlavor) -> String {
        guard flavor == .compliment else { return title }
        return Self.hypeTitles[id] ?? title
    }

    static let hypeTitles: [String: String] = [
        "classic": "Classic Toast",
        "ramsay": "Chef's Kiss",
        "mom": "Proud Mom",
        "disstrack": "Hype Track",
        "drill": "Proud Sergeant",
    ]

    static func == (lhs: RoastMode, rhs: RoastMode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension RoastMode {

    // MARK: - Catalog

    /// Dial order: the headliner first, then the guest lineup. Every comedian
    /// is pickable; the shutter is what the store gates.
    static let all: [RoastMode] = [classic] + guests

    static let classic = RoastMode(
        id: "classic",
        title: "Classic Roast",
        subtitle: "A headliner works the crowd",
        systemImage: "flame.fill",
        tint: .orange
    )

    static let guests: [RoastMode] = [
        RoastMode(
            id: "nature",
            title: "Nature Documentary",
            subtitle: "Narrated in the wild",
            systemImage: "leaf.fill",
            tint: .green
        ),
        RoastMode(
            id: "ramsay",
            title: "Angry Chef",
            subtitle: "This face is RAW",
            systemImage: "frying.pan.fill",
            tint: .red
        ),
        RoastMode(
            id: "mom",
            title: "Disappointed Mom",
            subtitle: "I'm not mad, just...",
            systemImage: "cup.and.saucer.fill",
            tint: .pink
        ),
        RoastMode(
            id: "shakespeare",
            title: "Shakespearean",
            subtitle: "Thou clay-brained lout",
            systemImage: "book.closed.fill",
            tint: .purple
        ),
        RoastMode(
            id: "disstrack",
            title: "Diss Track",
            subtitle: "Bars, not burns",
            systemImage: "music.mic",
            tint: .indigo
        ),
        RoastMode(
            id: "beautiful",
            title: "You're So Beautiful",
            subtitle: "Pure hype, zero burns",
            systemImage: "sparkles",
            tint: .yellow
        ),
        RoastMode(
            id: "fortune",
            title: "Fortune Teller",
            subtitle: "The face reveals all",
            systemImage: "moon.stars.fill",
            tint: .teal
        ),
        RoastMode(
            id: "drill",
            title: "Drill Sergeant",
            subtitle: "Drop and give me 20",
            systemImage: "figure.strengthtraining.traditional",
            tint: .brown
        ),
        RoastMode(
            id: "linkedin",
            title: "Corporate Influencer",
            subtitle: "Excited to announce…",
            systemImage: "briefcase.fill",
            tint: .blue
        ),
        RoastMode(
            id: "conspiracy",
            title: "Conspiracy Theorist",
            subtitle: "Wake up, sheeple",
            systemImage: "eye.trianglebadge.exclamationmark.fill",
            tint: .mint
        ),
        RoastMode(
            id: "pickup",
            title: "Pickup Lines",
            subtitle: "Smooth… ish",
            systemImage: "heart.circle.fill",
            tint: .red
        ),
        RoastMode(
            id: "datingbio",
            title: "Dating Bio",
            subtitle: "Swipe right on this",
            systemImage: "text.badge.star",
            tint: .pink
        ),
        RoastMode(
            id: "pet",
            title: "Pet Translator",
            subtitle: "If it's an animal…",
            systemImage: "pawprint.fill",
            tint: .orange
        )
    ]
}
