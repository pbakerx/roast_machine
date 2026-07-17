//
//  ModeTheme.swift
//  RoastMachine
//
//  Each mode dresses the whole screen as its own "scene" — a comedy club, a
//  kitchen, a red carpet — with matching colors, a face-positioning overlay,
//  and background motifs. This is the theming layer the Stage reads from.
//

import SwiftUI

struct ModeTheme {
    /// Short scene label shown under the dial, e.g. "COMEDY CLUB".
    let scene: String
    /// One-line direction shown by the face guide, e.g. "STEP INTO THE SPOTLIGHT".
    let hint: String

    let primary: Color        // main accent (glow, guide stroke)
    let secondary: Color      // supporting accent
    let backdrop: [Color]     // full-screen gradient when the camera is off

    /// SF Symbols sprinkled faintly across the scene backdrop.
    let motifs: [String]

    /// Shape of the face-positioning guide.
    let guide: GuideShape

    enum GuideShape { case spotlight, oval, plate, frame, diamond }
}

extension RoastMode {
    var theme: ModeTheme { ModeTheme.forMode(id) }
}

extension ModeTheme {
    static func forMode(_ id: String) -> ModeTheme {
        switch id {
        case "classic":
            return ModeTheme(scene: "COMEDY CLUB", hint: "STEP INTO THE SPOTLIGHT",
                             primary: .orange, secondary: .yellow,
                             backdrop: [Color(red: 0.35, green: 0.05, blue: 0.08), .black],
                             motifs: ["mic.fill", "star.fill", "music.note"],
                             guide: .spotlight)
        case "nature":
            return ModeTheme(scene: "THE WILD", hint: "FRAME THE SPECIMEN",
                             primary: .green, secondary: .mint,
                             backdrop: [Color(red: 0.05, green: 0.20, blue: 0.10), .black],
                             motifs: ["leaf.fill", "camera.macro", "tree.fill"],
                             guide: .oval)
        case "ramsay":
            return ModeTheme(scene: "THE KITCHEN", hint: "PLATE UP",
                             primary: .red, secondary: .orange,
                             backdrop: [Color(red: 0.10, green: 0.11, blue: 0.13), Color(red: 0.30, green: 0.06, blue: 0.03)],
                             motifs: ["flame.fill", "fork.knife", "frying.pan.fill"],
                             guide: .plate)
        case "mom":
            return ModeTheme(scene: "THE KITCHEN TABLE", hint: "SIT UP STRAIGHT",
                             primary: .pink, secondary: .orange,
                             backdrop: [Color(red: 0.30, green: 0.15, blue: 0.18), .black],
                             motifs: ["cup.and.saucer.fill", "heart.fill", "house.fill"],
                             guide: .oval)
        case "shakespeare":
            return ModeTheme(scene: "THE GLOBE", hint: "STRIKE A POSE",
                             primary: .purple, secondary: .yellow,
                             backdrop: [Color(red: 0.18, green: 0.08, blue: 0.28), .black],
                             motifs: ["book.closed.fill", "theatermasks.fill", "quote.bubble.fill"],
                             guide: .frame)
        case "disstrack":
            return ModeTheme(scene: "THE BOOTH", hint: "IN THE BOOTH",
                             primary: .indigo, secondary: .cyan,
                             backdrop: [Color(red: 0.08, green: 0.06, blue: 0.22), .black],
                             motifs: ["music.mic", "waveform", "flame.fill"],
                             guide: .diamond)
        case "beautiful":
            return ModeTheme(scene: "THE RED CARPET", hint: "WORK THE CAMERA",
                             primary: .yellow, secondary: .pink,
                             backdrop: [Color(red: 0.30, green: 0.20, blue: 0.02), Color(red: 0.25, green: 0.02, blue: 0.15)],
                             motifs: ["sparkles", "star.fill", "camera.fill"],
                             guide: .oval)
        case "fortune":
            return ModeTheme(scene: "THE MYSTIC TENT", hint: "GAZE INTO THE LENS",
                             primary: .teal, secondary: .purple,
                             backdrop: [Color(red: 0.05, green: 0.15, blue: 0.20), Color(red: 0.12, green: 0.04, blue: 0.24)],
                             motifs: ["moon.stars.fill", "sparkle", "hand.raised.fill"],
                             guide: .spotlight)
        case "drill":
            return ModeTheme(scene: "BOOT CAMP", hint: "EYES FORWARD, RECRUIT",
                             primary: .green, secondary: .red,
                             backdrop: [Color(red: 0.15, green: 0.16, blue: 0.10), .black],
                             motifs: ["figure.strengthtraining.traditional", "shield.fill", "flag.fill"],
                             guide: .frame)
        case "linkedin":
            return ModeTheme(scene: "THE OFFICE", hint: "PROFESSIONAL HEADSHOT",
                             primary: .blue, secondary: .cyan,
                             backdrop: [Color(red: 0.06, green: 0.10, blue: 0.20), .black],
                             motifs: ["briefcase.fill", "chart.line.uptrend.xyaxis", "person.crop.square.fill"],
                             guide: .frame)
        case "conspiracy":
            return ModeTheme(scene: "THE BUNKER", hint: "HOLD STILL, SUBJECT",
                             primary: .mint, secondary: .red,
                             backdrop: [Color(red: 0.08, green: 0.14, blue: 0.10), .black],
                             motifs: ["eye.fill", "map.fill", "exclamationmark.triangle.fill"],
                             guide: .frame)
        case "pickup":
            return ModeTheme(scene: "THE COCKTAIL BAR", hint: "GIVE 'EM A WINK",
                             primary: .red, secondary: .pink,
                             backdrop: [Color(red: 0.28, green: 0.05, blue: 0.12), .black],
                             motifs: ["heart.circle.fill", "wineglass.fill", "sparkles"],
                             guide: .oval)
        case "datingbio":
            return ModeTheme(scene: "THE DATING APP", hint: "BEST ANGLE",
                             primary: .pink, secondary: .purple,
                             backdrop: [Color(red: 0.25, green: 0.06, blue: 0.20), .black],
                             motifs: ["flame.fill", "heart.fill", "checkmark.seal.fill"],
                             guide: .oval)
        case "pet":
            return ModeTheme(scene: "THE LIVING ROOM", hint: "WHO'S A GOOD SUBJECT?",
                             primary: .orange, secondary: .teal,
                             backdrop: [Color(red: 0.22, green: 0.13, blue: 0.05), .black],
                             motifs: ["pawprint.fill", "house.fill", "heart.fill"],
                             guide: .oval)
        default:
            return ModeTheme(scene: "ON STAGE", hint: "CENTER YOUR FACE",
                             primary: .orange, secondary: .yellow,
                             backdrop: [Color(red: 0.20, green: 0.10, blue: 0.10), .black],
                             motifs: ["star.fill"],
                             guide: .oval)
        }
    }
}
