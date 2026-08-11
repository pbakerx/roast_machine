//
//  RoastArtService.swift
//  RoastMachine
//
//  Streams AI costume overlays into the show. GPT picks 2-3 wearable gag
//  props that riff on the roast ("a spaghetti wig", "tiny disappointed
//  reading glasses"), Gemini renders each on a solid green screen, and we
//  chroma-key the green away so the prop sits right on the user's face like
//  a photo-booth overlay. Same fan-out pattern as the Brock idea wall:
//  fire-and-forget requests, pop each prop in the moment it lands.
//
//  The Stage (live preview) uses the same pipeline with fixed per-persona
//  props, generated once per mode and cached on disk.
//

import UIKit

enum WearableSlot: String, CaseIterable, Codable {
    case head, eyes, mouth, neck

    /// Order props reveal in during playback.
    static let revealOrder: [WearableSlot] = [.head, .eyes, .mouth, .neck]
}

@MainActor
final class RoastArtService: ObservableObject {

    /// Roast-matched wearables for the current show, filled as each arrives.
    @Published private(set) var wearables: [WearableSlot: UIImage] = [:]

    /// Persona wearables for the Stage preview (cached per mode on disk).
    @Published private(set) var stageSet: [WearableSlot: UIImage] = [:]
    @Published private(set) var stageModeID: String?

    private var generation = 0
    private var tasks: [Task<Void, Never>] = []
    private var stageTask: Task<Void, Never>?

    private static let geminiEndpoint = URL(string:
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent")!
    private static let openAIEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    // MARK: - Roast wearables

    /// Kick off prop generation for a finished script. GPT invents the props
    /// (so they rhyme with the roast); Gemini draws them. Runs while the
    /// voice synthesizes, so props land mid-playback and visibly stream in.
    func generate(for script: String, mode: RoastMode) {
        cancel()
        guard AppConfig.hasGeminiKey else { return }
        let gen = generation

        let task = Task { [weak self] in
            var props = await Self.propIdeas(for: script, mode: mode)
            if props.isEmpty { props = Self.personaProps(for: mode.id) }
            props = Self.dedupeSlots(props)

            await withTaskGroup(of: (WearableSlot, UIImage?).self) { group in
                for (slot, prop) in props.prefix(3) {
                    group.addTask {
                        (slot, await Self.renderWearable(prop))
                    }
                }
                for await (slot, image) in group {
                    guard let self, !Task.isCancelled, self.generation == gen else { return }
                    if let image {
                        self.wearables[slot] = image
                    }
                }
            }
        }
        tasks.append(task)
    }

    func cancel() {
        generation += 1
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        wearables = [:]
    }

    // MARK: - Stage persona wearables

    /// Loads (or generates once and caches) the persona's signature props for
    /// the live Stage preview — the chef always gets the toque + mustache.
    func loadStageSet(for mode: RoastMode) {
        guard stageModeID != mode.id else { return }
        stageModeID = mode.id
        stageSet = [:]
        stageTask?.cancel()

        let props = Self.dedupeSlots(Self.personaProps(for: mode.id))
        let modeID = mode.id

        stageTask = Task { [weak self] in
            for (slot, prop) in props.prefix(2) {
                let cacheURL = Self.cacheURL(modeID: modeID, slot: slot)
                var image: UIImage?
                if let data = try? Data(contentsOf: cacheURL) {
                    image = UIImage(data: data)
                } else if AppConfig.hasGeminiKey {
                    image = await Self.renderWearable(prop)
                    if let png = image?.pngData() {
                        try? png.write(to: cacheURL)
                    }
                }
                guard let self, !Task.isCancelled, self.stageModeID == modeID else { return }
                if let image {
                    self.stageSet[slot] = image
                }
            }
        }
    }

    private static func cacheURL(modeID: String, slot: WearableSlot) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wearable_\(modeID)_\(slot.rawValue).png")
    }

    // MARK: - Prop selection

    /// Ask GPT for wearable gags that echo the roast. Cheap text call; any
    /// failure falls back to the persona's default props.
    private static func propIdeas(for script: String, mode: RoastMode) async -> [(WearableSlot, String)] {
        guard AppConfig.hasOpenAIKey else { return [] }

        let system = """
        You design photo-booth costume overlays for a roast-comedy app. Given a roast \
        transcript, invent exactly 3 wearable cartoon props that visually echo specific \
        things the roast says — the joke should land harder when the prop appears. \
        Each prop is a single front-facing wearable item (wig, hat, glasses, mustache, \
        beard, nose, necklace, collar...). Respond with ONLY a JSON array, no prose: \
        [{"prop": "short visual description", "slot": "head|eyes|mouth|neck"}] \
        Use 3 different slots.
        """
        let user = "PERSONA: \(mode.title)\nROAST: \(script.prefix(900))"

        var request = URLRequest(url: openAIEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppConfig.openAIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "gpt-4o-mini",
            "max_tokens": 220,
            "temperature": 1.0,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ])

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            var content = (choices.first?["message"] as? [String: Any])?["content"] as? String
        else { return [] }

        content = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let listData = content.data(using: .utf8),
            let items = try? JSONSerialization.jsonObject(with: listData) as? [[String: String]]
        else { return [] }

        return items.compactMap { item in
            guard let prop = item["prop"], !prop.isEmpty,
                  let slotRaw = item["slot"], let slot = WearableSlot(rawValue: slotRaw)
            else { return nil }
            return (slot, prop)
        }
    }

    /// Signature props per persona — the Stage look, and the fallback when
    /// the idea call fails.
    static func personaProps(for modeID: String) -> [(WearableSlot, String)] {
        switch modeID {
        case "classic":     return [(.head, "a slick vintage comedy-club fedora"),
                                    (.neck, "a big red velvet bow tie")]
        case "nature":      return [(.head, "a khaki safari explorer hat"),
                                    (.eyes, "small round field binoculars-style glasses")]
        case "ramsay":      return [(.head, "a tall white chef's toque"),
                                    (.mouth, "an angry twirled black mustache")]
        case "mom":         return [(.head, "pink foam hair curlers on a headband"),
                                    (.neck, "a strand of prim white pearls")]
        case "shakespeare": return [(.head, "a plumed velvet Elizabethan cap"),
                                    (.neck, "a white pleated Elizabethan ruff collar")]
        case "disstrack":   return [(.head, "a backwards snapback cap"),
                                    (.neck, "a chunky gold rope chain with a medallion")]
        case "beautiful":   return [(.head, "a sparkling golden tiara with pink gems"),
                                    (.eyes, "glamorous oversized rhinestone sunglasses")]
        case "fortune":     return [(.head, "a teal mystic turban with an amethyst brooch"),
                                    (.eyes, "hypnotic swirling spiral glasses")]
        case "drill":       return [(.head, "an olive drill-sergeant campaign hat"),
                                    (.mouth, "a silver drill-sergeant whistle on a lanyard")]
        case "linkedin":    return [(.eyes, "serious rectangular business glasses"),
                                    (.neck, "a corporate blue power tie on a white collar")]
        case "conspiracy":  return [(.head, "a crinkled tinfoil cone hat"),
                                    (.eyes, "paranoid wide bloodshot cartoon eyes glasses")]
        case "pickup":      return [(.mouth, "a red rose held in the teeth"),
                                    (.neck, "an open crimson collar with a gold medallion")]
        case "datingbio":   return [(.eyes, "pink heart-shaped sunglasses"),
                                    (.head, "a halo of tiny floating hearts")]
        case "pet":         return [(.head, "an orange cat-ear headband"),
                                    (.mouth, "cartoon cat whiskers and a little pink nose")]
        default:            return [(.head, "a slick vintage comedy-club fedora")]
        }
    }

    private static func dedupeSlots(_ props: [(WearableSlot, String)]) -> [(WearableSlot, String)] {
        var seen = Set<WearableSlot>()
        return props.filter { seen.insert($0.0).inserted }
    }

    // MARK: - Rendering

    /// Green-screen prompt + chroma key = transparent costume overlay.
    private static func renderWearable(_ prop: String) async -> UIImage? {
        let prompt = "Photo-booth costume overlay art: \(prop). " +
            "A single front-facing, perfectly centered, symmetrical cartoon prop with bold " +
            "thick outlines, vibrant colors, and a comic-sticker style. The prop fills most " +
            "of the frame. Isolated on a completely solid, uniform PURE GREEN background " +
            "(#00FF00) — every pixel that is not the prop must be exactly that green. " +
            "No text, no shadows, no gradients, no reflections, nothing else in frame. " +
            "Square 1:1."

        for attempt in 0..<2 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 900_000_000) }
            if Task.isCancelled { return nil }
            if let raw = try? await requestGeminiImage(prompt: prompt),
               let keyed = chromaKeyGreen(raw) {
                return keyed
            }
        }
        return nil
    }

    private static func requestGeminiImage(prompt: String) async throws -> UIImage? {
        var request = URLRequest(url: geminiEndpoint)
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

    /// Removes the green screen: green-dominant pixels go transparent, and
    /// surviving pixels get a de-spill so props don't glow radioactive.
    private static func chromaKeyGreen(_ image: UIImage) -> UIImage? {
        let maxSide: CGFloat = 640
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let width = Int(image.size.width * scale)
        let height = Int(image.size.height * scale)
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cg = image.cgImage else { return nil }
        context.interpolationQuality = .high
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let buffer = context.data else { return nil }

        let pixels = buffer.bindMemory(to: UInt8.self, capacity: width * height * 4)
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            if g > 90 && g > (r * 135) / 100 && g > (b * 135) / 100 {
                pixels[i] = 0; pixels[i + 1] = 0; pixels[i + 2] = 0; pixels[i + 3] = 0
            } else if g > max(r, b) {
                pixels[i + 1] = UInt8(max(r, b))   // de-spill green fringe
            }
        }

        guard let keyed = context.makeImage() else { return nil }
        return UIImage(cgImage: keyed, scale: 1, orientation: .up)
    }
}
