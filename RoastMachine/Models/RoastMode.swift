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

    static func == (lhs: RoastMode, rhs: RoastMode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension RoastMode {

    /// A 3–4 word taste of the persona, spoken by the voice-preview button in ROAST mode.
    var previewLine: String {
        switch id {
        case "classic":     return "Look at this guy!"
        case "nature":      return "Remarkable. Truly remarkable."
        case "ramsay":      return "It's RAW!!"
        case "mom":         return "I'm not mad."
        case "shakespeare": return "Thou art absurd!"
        case "disstrack":   return "Yo, check it."
        case "beautiful":   return "You look INCREDIBLE!"
        case "fortune":     return "I see... trouble."
        case "drill":       return "Drop and give twenty!"
        case "linkedin":    return "Thrilled to announce..."
        case "conspiracy":  return "Wake up, sheeple!"
        case "pickup":      return "Hey there, gorgeous."
        case "datingbio":   return "Swipe right. Obviously."
        case "pet":         return "Feed me, human."
        default:            return "Get roasted!"
        }
    }

    /// The HYPE-mode taste, spoken by the preview button when the rocker is on HYPE.
    var hypePreviewLine: String {
        switch id {
        case "classic":     return "You're a LEGEND!"
        case "nature":      return "A majestic creature!"
        case "ramsay":      return "Stunning. Chef's kiss!"
        case "mom":         return "I'm SO proud of you!"
        case "shakespeare": return "Thou art radiant!"
        case "disstrack":   return "Crown on your head!"
        case "beautiful":   return "You look INCREDIBLE!"
        case "fortune":     return "I see... greatness!"
        case "drill":       return "Outstanding, soldier!"
        case "linkedin":    return "Thrilled to celebrate you!"
        case "conspiracy":  return "Too perfect to be real!"
        case "pickup":      return "Hey there, royalty."
        case "datingbio":   return "Instant swipe right!"
        case "pet":         return "My human is PERFECT!"
        default:            return "Your Majesty!"
        }
    }

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
