//
//  RoastEngine.swift
//  RoastMachine
//
//  Orchestrates the pipeline: image + mode -> OpenAI script -> ElevenLabs audio.
//

import UIKit

@MainActor
final class RoastEngine: ObservableObject {

    enum Phase: Equatable {
        case idle
        case writing        // vision model composing the bit
        case voicing        // ElevenLabs synthesizing audio
        case ready
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var script: String = ""
    @Published private(set) var audio: Data?
    @Published private(set) var mode: RoastMode?
    @Published private(set) var image: UIImage?

    let voice = VoiceService()
    private let scripts = RoastScriptService()

    var isBusy: Bool {
        switch phase {
        case .writing, .voicing: return true
        default: return false
        }
    }

    func run(image: UIImage, mode: RoastMode) async {
        self.image = image
        self.mode = mode
        self.audio = nil
        self.script = ""

        do {
            phase = .writing
            let text = try await scripts.generateScript(for: image, mode: mode)
            script = text

            phase = .voicing
            let data = try await voice.synthesize(text: text, voiceID: mode.voiceID)
            audio = data

            phase = .ready
            voice.play(data)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = .failed(message)
        }
    }

    func replay() {
        guard let audio else { return }
        voice.togglePlayback(audio)
    }

    func reset() {
        voice.stop()
        phase = .idle
        script = ""
        audio = nil
        mode = nil
        image = nil
    }
}
