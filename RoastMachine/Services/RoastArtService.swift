//
//  RoastArtService.swift
//  RoastMachine
//
//  Streams AI art into the show. For each concrete noun the roast mentions,
//  a Gemini image is generated concurrently and pinned onto the screen the
//  moment it arrives — the same fire-and-forget fan-out pattern as the Brock
//  Institute idea wall (no polling, no SSE; the "stream" is completion order).
//  Emojis remain the instant fallback while an image is in flight or if the
//  API fails.
//

import UIKit

@MainActor
final class RoastArtService: ObservableObject {

    /// Finished art keyed by RoastStickers.Event.id. ResultView swaps these
    /// in over the emoji as they land.
    @Published private(set) var images: [Int: UIImage] = [:]

    private var generation = 0          // bumped on reset to orphan stale tasks
    private var tasks: [Task<Void, Never>] = []

    private static let endpoint = URL(string:
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent")!

    /// Rotating art styles so consecutive stickers look like different hands
    /// made them (ported from the Brock style dictionary, tuned for comedy).
    private static let styles = [
        "a bold vintage comedy-club poster illustration, screen-printed, grainy and punchy",
        "a two-color risograph print — grainy, slightly mis-registered layers, bold flat shapes",
        "a hand-cut paper collage with torn edges and found-paper textures",
        "a chunky retro cartoon sticker with thick outlines and juicy highlights",
        "a woodcut print with rough, energetic carve marks",
        "a loose, saturated gouache painting with confident brushwork"
    ]

    /// Kick off art for the roast's sticker events. Called as soon as the
    /// script exists — images generate while ElevenLabs is still synthesizing,
    /// so most arrive during playback and visibly stream in.
    func generate(for script: String, mode: RoastMode) {
        cancel()
        guard AppConfig.hasGeminiKey else { return }
        let gen = generation
        let events = Array(RoastStickers.events(for: script).prefix(6))
        guard !events.isEmpty else { return }

        let cohesion = "It is one sticker in a matching set decorating a \"\(mode.theme.scene.lowercased())\" comedy roast, so keep a cohesive, playful mood."

        // In-flight cap of 4: chunk the events into two waves.
        for (index, event) in events.enumerated() {
            let style = Self.styles[index % Self.styles.count]
            let delay = index < 4 ? 0.0 : 2.5
            let task = Task { [weak self] in
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                guard !Task.isCancelled else { return }
                let subject = Self.subject(for: event.emoji, in: script)
                let image = await Self.fetchImage(style: style, subject: subject, cohesion: cohesion)
                guard let self, !Task.isCancelled, self.generation == gen, let image else { return }
                self.images[event.id] = image
            }
            tasks.append(task)
        }
    }

    func cancel() {
        generation += 1
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        images = [:]
    }

    // MARK: - Private

    /// Recover the actual word that triggered the sticker so Gemini draws the
    /// roast's noun, not a description of the emoji.
    private static func subject(for emoji: String, in script: String) -> String {
        for rawWord in script.split(separator: " ") {
            let word = rawWord.lowercased().trimmingCharacters(in: .alphanumerics.inverted)
            guard !word.isEmpty else { continue }
            let candidates = [word,
                              word.hasSuffix("s") ? String(word.dropLast()) : word,
                              word.hasSuffix("es") ? String(word.dropLast(2)) : word]
            for c in candidates where RoastStickers.lexicon[c] == emoji {
                return c
            }
        }
        return emoji // worst case: the emoji itself still describes the subject
    }

    /// One generation attempt + one retry, 45s timeout, silent failure —
    /// the show never waits on art.
    private static func fetchImage(style: String, subject: String, cohesion: String) async -> UIImage? {
        let prompt = "Create \(style), depicting: a \(subject). \(cohesion) " +
            "A single striking, hand-made composition — richly colored, textured, full of character. " +
            "One bold subject filling the whole square frame edge to edge. " +
            "No text, no words, no lettering, no logos, and no photorealism. " +
            "Square 1:1 composition. Tasteful and appropriate for all audiences."

        for attempt in 0..<2 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
            if Task.isCancelled { return nil }
            if let image = try? await requestOnce(prompt: prompt) {
                return image
            }
        }
        return nil
    }

    private static func requestOnce(prompt: String) async throws -> UIImage? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.geminiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseModalities": ["IMAGE"]]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let inline = parts.compactMap({ $0["inlineData"] as? [String: Any] }).first,
            let base64 = inline["data"] as? String,
            let bytes = Data(base64Encoded: base64)
        else { return nil }
        return UIImage(data: bytes)
    }
}
