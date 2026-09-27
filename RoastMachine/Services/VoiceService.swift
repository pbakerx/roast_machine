//
//  VoiceService.swift
//  RoastMachine
//
//  Plays the show's audio (voiced on the server) and the bundled voice previews.
//

import AVFoundation

@MainActor
final class VoiceService: NSObject, ObservableObject {

    @Published var isPlaying = false

    var duration: TimeInterval { player?.duration ?? 0 }

    private var player: AVAudioPlayer?

    /// Plays mp3 data. Configures the audio session so it's audible even on silent mode.
    func play(_ data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let newPlayer = try AVAudioPlayer(data: data)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            player = newPlayer
            newPlayer.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        isPlaying = false
    }

    // MARK: - Voice preview

    /// Mode id currently synthesizing/speaking its preview line, for UI spinners.
    @Published var previewingModeID: String?

    /// Plays the mode's short preview line, pre-recorded into the app bundle so
    /// auditioning voices costs nothing.
    func preview(_ mode: RoastMode) async {
        if previewingModeID != nil { return }
        guard let url = Bundle.main.url(forResource: "preview_\(mode.id)", withExtension: "mp3"),
              let data = try? Data(contentsOf: url) else { return }
        previewingModeID = mode.id
        play(data)
        try? await Task.sleep(for: .milliseconds(400))
        previewingModeID = nil
    }

    func togglePlayback(_ data: Data) {
        if isPlaying {
            stop()
        } else {
            play(data)
        }
    }
}

extension VoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
        }
    }
}
