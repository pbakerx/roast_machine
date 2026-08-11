//
//  ResultView.swift
//  RoastMachine
//
//  The show itself. Audio-first: your photo fills the screen, the voice rips,
//  and big comedy graphics slam in as the words land. The transcript hides
//  behind a small pill — the roast is a thing you HEAR.
//

import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var engine: RoastEngine
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var showShare = false
    @State private var showTranscript = false
    @State private var showPaywall = false
    @State private var crankPulse = false
    @State private var exportingVideo = false
    @State private var exportedVideoURL: URL?

    private var theme: ModeTheme? { engine.mode?.theme }
    private var stickerEvents: [RoastStickers.Event] {
        RoastStickers.events(for: engine.script)
    }

    var body: some View {
        ZStack {
            photoLayer
            scrim

            if let mode = engine.mode, engine.image != nil {
                CostumeOverlayView(modeID: mode.id)
            }

            if case .ready = engine.phase {
                StickerStreamLayer(events: stickerEvents,
                                   progress: engine.voice.playbackFraction)
            }

            VStack {
                topChip
                Spacer()
                bottomStack
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
        .sheet(isPresented: $showShare) { ShareSheet(items: shareItems()) }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
        .sheet(isPresented: $showTranscript) { transcriptSheet }
        .onAppear { crankPulse = true }
    }

    // MARK: - Layers

    @ViewBuilder
    private var photoLayer: some View {
        GeometryReader { geo in
            if let image = engine.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else if let theme {
                ThematicBackdrop(theme: theme)
            }
        }
        .ignoresSafeArea()
    }

    private var scrim: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.7), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 320)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topChip: some View {
        HStack {
            if let mode = engine.mode {
                HStack(spacing: 8) {
                    Image(systemName: mode.systemImage)
                        .foregroundStyle(mode.theme.primary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(mode.theme.scene)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(mode.theme.primary)
                        Text(mode.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.black.opacity(0.55), in: Capsule())
            }
            Spacer()
            Text("● ON AIR")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.red)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.black.opacity(0.6), in: Capsule())
        }
    }

    // MARK: - Bottom stack per phase

    @ViewBuilder
    private var bottomStack: some View {
        switch engine.phase {
        case .writing:
            stagePlaceholder("WRITING YOUR BIT…", symbol: "pencil.and.scribble")
        case .voicing:
            stagePlaceholder("WARMING UP THE MIC…", symbol: "waveform")
        case .failed(let message):
            errorView(message)
        case .ready, .idle:
            readyControls
        }
    }

    private func stagePlaceholder(_ label: String, symbol: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(theme?.primary ?? .orange)
                .symbolEffect(.pulse)
            Text(label)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white)
            ProgressView().tint(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 28))
        .padding(.bottom, 8)
    }

    private var readyControls: some View {
        VStack(spacing: 14) {
            if engine.voice.isPlaying {
                crankBanner
            }

            HStack(spacing: 20) {
                // words, tucked away — this show is audio-first
                controlButton(system: "text.quote", label: "Words") {
                    showTranscript = true
                }

                Button {
                    engine.replay()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(colors: [theme?.primary ?? .orange,
                                                        (theme?.primary ?? .orange).opacity(0.7)],
                                               center: .init(x: 0.4, y: 0.35),
                                               startRadius: 4, endRadius: 46)
                            )
                            .frame(width: 88, height: 88)
                            .shadow(color: (theme?.primary ?? .orange).opacity(0.8),
                                    radius: engine.voice.isPlaying ? 20 : 10)
                        Image(systemName: engine.voice.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }

                controlButton(system: exportingVideo ? "hourglass" : "square.and.arrow.up",
                              label: exportingVideo ? "Baking…" : "Share") {
                    shareTapped()
                }
                .disabled(exportingVideo)
            }

            Button {
                dismiss()
            } label: {
                Text("ROAST ME AGAIN")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(.white.opacity(0.12), in: Capsule())
            }

            if !store.hasAllModes {
                upsellRibbon
            }
        }
        .padding(.bottom, 4)
    }

    /// The audio IS the product — tell them to get loud.
    private var crankBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.wave.3.fill")
                .symbolEffect(.variableColor.iterative, isActive: true)
            Text("CRANK IT UP")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .tracking(3)
            Image(systemName: "arrow.up.circle.fill")
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(
            LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing),
            in: Capsule()
        )
        .shadow(color: .orange.opacity(0.8), radius: crankPulse ? 18 : 6)
        .scaleEffect(crankPulse ? 1.05 : 0.97)
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: crankPulse)
    }

    private var upsellRibbon: some View {
        Button {
            showPaywall = true
        } label: {
            Text("😈 13 more voices want a word with you — $1.99")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.white.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(.yellow.opacity(0.5), lineWidth: 1))
        }
    }

    private func controlButton(system: String, label: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: system)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 56, height: 56)
                    .background(.black.opacity(0.5), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
            Button("Back") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 24))
        .padding(.bottom, 8)
    }

    private var transcriptSheet: some View {
        NavigationStack {
            ScrollView {
                Text("“\(engine.script)”")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(24)
            }
            .navigationTitle("The Words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { showTranscript = false }
                }
            }
            .presentationDetents([.medium])
        }
    }

    /// Share is video-first: bake the MP4 (photo + audio + stickers) once,
    /// then reuse it. Falls back to the raw mp3 if the export fails.
    private func shareTapped() {
        if exportedVideoURL != nil {
            showShare = true
            return
        }
        guard let image = engine.image, let audio = engine.audio, let mode = engine.mode else {
            showShare = true
            return
        }
        exportingVideo = true
        let script = engine.script
        Task {
            defer { exportingVideo = false }
            exportedVideoURL = try? await VideoExporter.export(
                image: image, audio: audio, script: script, mode: mode)
            showShare = true
        }
    }

    private func shareItems() -> [Any] {
        var items: [Any] = []
        if !engine.script.isEmpty {
            items.append("My Roast Machine bit: \(engine.script)")
        }
        if let video = exportedVideoURL {
            items.append(video)
        } else if let audio = engine.audio {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("roast.mp3")
            try? audio.write(to: url)
            items.append(url)
        }
        return items
    }
}

// MARK: - Sticker stream

/// Big emoji graphics that pop in as their word lands in the audio, wobble,
/// and hang around like props on the stage. Max a handful visible at once.
private struct StickerStreamLayer: View {
    let events: [RoastStickers.Event]
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let live = events.filter { $0.fraction <= progress }
            let visible = live.suffix(5)
            ForEach(Array(visible), id: \.id) { event in
                StickerPop(event: event)
                    .position(x: geo.size.width * event.x,
                              y: geo.size.height * event.y)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StickerPop: View {
    let event: RoastStickers.Event
    @State private var shown = false

    var body: some View {
        Text(event.emoji)
            .font(.system(size: event.size))
            .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
            .rotationEffect(.degrees(shown ? event.rotation : event.rotation - 30))
            .scaleEffect(shown ? 1 : 0.1)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    shown = true
                }
            }
    }
}
