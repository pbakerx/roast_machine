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
        soldOutPlaying = false
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
        soldOutPlaying = false
        player?.stop()
        isPlaying = false
    }

    // MARK: - Voice preview

    /// Voice id whose sample is playing, for the picker's speaker icon.
    @Published var previewingID: String?

    /// Plays a voice's sample line for the given flavor, pre-recorded into the
    /// app bundle so auditioning voices costs nothing.
    func previewVoice(_ voice: Voice, flavor: RoastFlavor) async {
        let name = "voice_\(voice.id)_\(flavor == .compliment ? "hype" : "roast")"
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
              let data = try? Data(contentsOf: url) else { return }
        previewingID = voice.id
        play(data)
        try? await Task.sleep(for: .seconds(duration > 0 ? duration : 1.5))
        if previewingID == voice.id { previewingID = nil }
    }

    // MARK: - Sold out

    private var soldOutPlaying = false

    /// The out-of-tickets roast for this strike (1-3), in the player's voice.
    func playSoldOut(_ voice: Voice, strike: Int) {
        guard let url = Bundle.main.url(forResource: "soldout_\(voice.id)_\(strike)", withExtension: "mp3"),
              let data = try? Data(contentsOf: url) else { return }
        play(data)
        soldOutPlaying = true
    }

    /// A purchase landed: no need to keep telling them off.
    func stopSoldOut() {
        guard soldOutPlaying else { return }
        stop()
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
