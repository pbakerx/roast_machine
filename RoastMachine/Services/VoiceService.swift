//
//  VoiceService.swift
//  RoastMachine
//
//  Turns the roast text into speech using the ElevenLabs text-to-speech REST API,
//  then plays it back with AVAudioPlayer.
//

import AVFoundation

@MainActor
final class VoiceService: NSObject, ObservableObject {

    @Published var isPlaying = false
    /// 0...1 through the current clip. Drives the streamed sticker overlays.
    @Published var playbackFraction: Double = 0

    var duration: TimeInterval { player?.duration ?? 0 }

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private let session = URLSession.shared

    /// Fetches spoken audio (mp3 data) for the given text + ElevenLabs voice.
    func synthesize(text: String, voiceID: String) async throws -> Data {
        guard AppConfig.hasElevenLabsKey else { throw RoastError.missingElevenLabsKey }

        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.elevenLabsKey, forHTTPHeaderField: "xi-api-key")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.4,
                "similarity_boost": 0.75,
                "style": 0.6,
                "use_speaker_boost": true
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RoastError.emptyResponse }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw RoastError.http(http.statusCode, String(msg.prefix(200)))
        }
        guard !data.isEmpty else { throw RoastError.emptyResponse }
        return data
    }

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
            playbackFraction = 0
            startProgressTimer()
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        isPlaying = false
        progressTimer?.invalidate()
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.playbackFraction = player.duration > 0
                    ? player.currentTime / player.duration : 0
            }
        }
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
            self.playbackFraction = 1
            self.progressTimer?.invalidate()
        }
    }
}
