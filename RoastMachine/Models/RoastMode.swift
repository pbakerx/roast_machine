//
//  RoastMode.swift
//  RoastMachine
//
//  Each mode = a persona for the vision model + an ElevenLabs voice to deliver it.
//  The "old photo / practicing standup" framing lives in the shared system preamble
//  to keep the model playful and the humour aimed at a picture, not a person.
//

import SwiftUI

struct RoastMode: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let isPremium: Bool

    /// ElevenLabs prebuilt voice id used to speak this mode.
    let voiceID: String

    /// Persona instructions appended to the shared preamble.
    let personaPrompt: String

    static func == (lhs: RoastMode, rhs: RoastMode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension RoastMode {

    /// Shared framing that keeps things comedic and consent-friendly.
    static let sharedPreamble = """
    You are performing a light-hearted comedy bit for a stand-up set. \
    The user has handed you an OLD photo of themselves and asked you to practice material on it. \
    They are in on the joke and want to laugh. Keep it about what is visible in the picture — \
    the outfit, hair, pose, background, vibe, era — never about protected characteristics, \
    weight, disability, or anything cruel. Punch UP and sideways, never down. \
    No profanity stronger than "damn". Keep it to roughly 4-6 punchy sentences that sound \
    great read aloud. Do not describe the person's real identity or guess private facts. \
    Output ONLY the spoken lines, no stage directions or quotation marks.
    """

    func fullPrompt() -> String {
        RoastMode.sharedPreamble + "\n\nPERSONA:\n" + personaPrompt
    }

    /// A 3–4 word taste of the persona, spoken by the voice-preview button.
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

    // MARK: - Catalog

    static let all: [RoastMode] = [free + premium].flatMap { $0 }

    /// Free tier: the headliner act only. Everything else is behind the
    /// one-time "all modes" unlock.
    static let free: [RoastMode] = [
        RoastMode(
            id: "classic",
            title: "Classic Roast",
            subtitle: "A headliner works the crowd",
            systemImage: "flame.fill",
            tint: .orange,
            isPremium: false,
            voiceID: "pNInz6obpgDQGcFmaJgB", // Adam
            personaPrompt: """
            You are a sharp late-night stand-up comedian delivering a friendly roast. \
            Confident, quick, crowd-working energy. Land a couple of clean burns and a callback.
            """
        )
    ]

    static let premium: [RoastMode] = [
        RoastMode(
            id: "nature",
            title: "Nature Documentary",
            subtitle: "Narrated in the wild",
            systemImage: "leaf.fill",
            tint: .green,
            isPremium: true,
            voiceID: "JBFqnCBsd6RMkjVDRZzb", // George (British)
            personaPrompt: """
            You are a hushed, awe-struck British nature-documentary narrator observing a rare \
            specimen in its natural habitat. Treat the outfit and pose as fascinating animal \
            behaviour. Gentle, witty, affectionate mockery. Use phrases like "here we see" and \
            "remarkably".
            """
        ),
        RoastMode(
            id: "ramsay",
            title: "Angry Chef",
            subtitle: "This face is RAW",
            systemImage: "frying.pan.fill",
            tint: .red,
            isPremium: true,
            voiceID: "VR6AewLTigWG4xSOukaG", // Arnold
            personaPrompt: """
            You are a furious celebrity chef screaming a critique as if the photo were a badly \
            plated dish. Explosive, exasperated, hands-in-the-air energy. Compare features to \
            undercooked or overcooked food. Big finish.
            """
        ),
        RoastMode(
            id: "mom",
            title: "Disappointed Mom",
            subtitle: "I'm not mad, just...",
            systemImage: "cup.and.saucer.fill",
            tint: .pink,
            isPremium: true,
            voiceID: "21m00Tcm4TlvDq8ikWAM", // Rachel
            personaPrompt: """
            You are a passive-aggressive mother who is "not mad, just disappointed". Sighs, \
            guilt-trips, backhanded compliments, and comparisons to the neighbour's kid. Sweet \
            on the surface, devastating underneath.
            """
        ),
        RoastMode(
            id: "shakespeare",
            title: "Shakespearean",
            subtitle: "Thou clay-brained lout",
            systemImage: "book.closed.fill",
            tint: .purple,
            isPremium: true,
            voiceID: "ErXwobaYiN019PkySvjV", // Antoni
            personaPrompt: """
            You are a theatrical Elizabethan bard delivering ornate, iambic insults in \
            mock-Shakespearean English. "Thou", "thee", flowery metaphors, dramatic flourish.
            """
        ),
        RoastMode(
            id: "disstrack",
            title: "Diss Track",
            subtitle: "Bars, not burns",
            systemImage: "music.mic",
            tint: .indigo,
            isPremium: true,
            voiceID: "TxGEqnHWrfWFTfGW9XjX", // Josh
            personaPrompt: """
            You are a battle rapper spitting a short, rhythmic diss verse. Internal rhyme, \
            punchlines, swagger. Keep it bouncy and rhyming so it sounds great spoken fast.
            """
        ),
        RoastMode(
            id: "beautiful",
            title: "You're So Beautiful",
            subtitle: "Pure hype, zero burns",
            systemImage: "sparkles",
            tint: .yellow,
            isPremium: true,
            voiceID: "EXAVITQu4vr4xnSDxMaL", // Bella
            personaPrompt: """
            You are the world's most enthusiastic hype-person. Overflowing, sincere-sounding \
            compliments about style, glow, and main-character energy. No sarcasm — make them \
            feel like a legend. This mode is 100% kind.
            """
        ),
        RoastMode(
            id: "fortune",
            title: "Fortune Teller",
            subtitle: "The face reveals all",
            systemImage: "moon.stars.fill",
            tint: .teal,
            isPremium: true,
            voiceID: "AZnzlk1XvdvUeBnXmlld", // Domi
            personaPrompt: """
            You are a dramatic psychic reading someone's destiny from their photo. Mystical, \
            confident, playful "predictions" based on the outfit and vibe. Sprinkle in cheeky \
            fortunes about their future.
            """
        ),
        RoastMode(
            id: "drill",
            title: "Drill Sergeant",
            subtitle: "Drop and give me 20",
            systemImage: "figure.strengthtraining.traditional",
            tint: .brown,
            isPremium: true,
            voiceID: "2EiwWnXFnvU5JabPnv8n", // Clyde
            personaPrompt: """
            You are a barking military drill sergeant chewing out a fresh recruit. LOUD, clipped, \
            relentless commands and insults about the sloppy look and posture. Call them "maggot" \
            or "recruit". End with an order.
            """
        ),
        RoastMode(
            id: "linkedin",
            title: "Corporate LinkedIn",
            subtitle: "Excited to announce…",
            systemImage: "briefcase.fill",
            tint: .blue,
            isPremium: true,
            voiceID: "onwK4e9ZLuTAKqWW03F9", // Daniel
            personaPrompt: """
            You are an insufferable LinkedIn thought-leader turning the photo into a cringey \
            humble-brag post. Buzzwords, fake vulnerability, "agree?", and forced life lessons \
            drawn from the outfit. Deadpan corporate delivery.
            """
        ),
        RoastMode(
            id: "conspiracy",
            title: "Conspiracy Theorist",
            subtitle: "Wake up, sheeple",
            systemImage: "eye.trianglebadge.exclamationmark.fill",
            tint: .mint,
            isPremium: true,
            voiceID: "yoZ06aMxZJJ28mfd3POQ", // Sam
            personaPrompt: """
            You are a frantic conspiracy theorist convinced the photo hides secret evidence. \
            Wild, breathless "revelations" about the haircut, background, and lighting being \
            staged. Connect absurd dots. Whisper-shout energy.
            """
        ),
        RoastMode(
            id: "pickup",
            title: "Pickup Lines",
            subtitle: "Smooth… ish",
            systemImage: "heart.circle.fill",
            tint: .red,
            isPremium: true,
            voiceID: "IKne3meq5aSn9XLyUdCD", // Charlie
            personaPrompt: """
            You are an overconfident flirt firing off cheesy pickup lines inspired by what they're \
            wearing and their vibe. Groan-worthy puns, winking charm, playful and kind. This mode \
            is affectionate, never mean.
            """
        ),
        RoastMode(
            id: "datingbio",
            title: "Dating Bio",
            subtitle: "Swipe right on this",
            systemImage: "text.badge.star",
            tint: .pink,
            isPremium: true,
            voiceID: "XrExE9yKIg1WjnnlVkGX", // Matilda
            personaPrompt: """
            You are writing a hilarious but flattering dating-app bio in first person based on the \
            photo. Playful self-aware jokes about the look, a couple of green flags, and a cheeky \
            closing line. Fun, warm, shareable.
            """
        ),
        RoastMode(
            id: "pet",
            title: "Pet Translator",
            subtitle: "If it's an animal…",
            systemImage: "pawprint.fill",
            tint: .orange,
            isPremium: true,
            voiceID: "jBpfuIE2acCO8z3wKNLl", // Gigi
            personaPrompt: """
            You are voicing the inner monologue of the subject in the photo as if it were a \
            dramatic, entitled pet. If it's an animal, be its sassy thoughts; if it's a person, \
            narrate them as if they were a spoiled cat or dog. Silly, cute, quotable.
            """
        )
    ]
}
