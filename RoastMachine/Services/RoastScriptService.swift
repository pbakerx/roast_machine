//
//  RoastScriptService.swift
//  RoastMachine
//
//  Sends the photo + chosen persona to OpenAI's vision model and gets back
//  the spoken roast/compliment script.
//

import UIKit

enum RoastError: LocalizedError {
    case missingOpenAIKey
    case missingElevenLabsKey
    case badImage
    case http(Int, String)
    case emptyResponse
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingOpenAIKey:
            return "No OpenAI key found. Add OPENAI_API_KEY to Secrets.xcconfig."
        case .missingElevenLabsKey:
            return "No ElevenLabs key found. Add ELEVENLABS_API_KEY to Secrets.xcconfig."
        case .badImage:
            return "That image couldn't be processed. Try another one."
        case .http(let code, let msg):
            return "Server error (\(code)). \(msg)"
        case .emptyResponse:
            return "The comedian went quiet. Try again."
        case .decoding:
            return "Couldn't read the response. Try again."
        }
    }
}

struct RoastScriptService {

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o" // vision-capable

    func generateScript(for image: UIImage, mode: RoastMode,
                        flavor: RoastFlavor = .roast) async throws -> String {
        guard AppConfig.hasOpenAIKey else { throw RoastError.missingOpenAIKey }
        guard let base64 = jpegBase64(from: image) else { throw RoastError.badImage }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 320,
            "temperature": 0.9,
            "messages": [
                ["role": "system", "content": mode.fullPrompt(flavor: flavor)],
                ["role": "user", "content": [
                    ["type": "text", "text": "Here is the old photo. Give me the bit."],
                    ["type": "image_url", "image_url": [
                        "url": "data:image/jpeg;base64,\(base64)",
                        "detail": "low"
                    ]]
                ]]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppConfig.openAIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RoastError.emptyResponse }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw RoastError.http(http.statusCode, String(msg.prefix(200)))
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw RoastError.decoding }

        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw RoastError.emptyResponse }
        return cleaned
    }

    private func jpegBase64(from image: UIImage) -> String? {
        // Downscale to keep the upload small and fast.
        let maxDimension: CGFloat = 768
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.7)?.base64EncodedString()
    }
}
