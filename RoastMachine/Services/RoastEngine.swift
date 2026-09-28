//
//  RoastEngine.swift
//  RoastMachine
//
//  Orchestrates a show: photo + mode -> server writes the bit -> server voices it.
//

import Combine
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
    @Published private(set) var flavor: RoastFlavor = .roast
    @Published private(set) var image: UIImage?

    let voice = VoiceService()
    private let backend = Backend.shared
    private var forwarders: [AnyCancellable] = []

    init() {
        // Nested ObservableObjects don't propagate through @EnvironmentObject —
        // views observing the engine would never re-render for playback progress.
        // Forward their change notifications through ours.
        forwarders = [
            voice.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        ]
    }

    var isBusy: Bool {
        switch phase {
        case .writing, .voicing: return true
        default: return false
        }
    }

    func run(image: UIImage, mode: RoastMode, flavor: RoastFlavor, voiceID: String, store: StoreManager) async {
        self.image = image
        self.mode = mode
        self.flavor = flavor
        self.audio = nil
        self.script = ""

        do {
            phase = .writing
            let show = try await backend.show(image: image, modeID: mode.id, flavor: flavor)
            store.apply(show.wallet)
            script = show.script

            phase = .voicing
            let data = try await backend.voice(showID: show.showId, voice: voiceID)
            audio = data

            phase = .ready
            voice.play(data)
        } catch {
            store.apply((error as? BackendError)?.wallet)
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
