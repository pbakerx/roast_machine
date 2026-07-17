//
//  ResultView.swift
//  RoastMachine
//
//  Shows progress, the finished transcript, playback controls, and sharing.
//

import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var engine: RoastEngine
    @Environment(\.dismiss) private var dismiss

    @State private var showShare = false

    var body: some View {
        VStack(spacing: 24) {
            if let image = engine.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(alignment: .topLeading) {
                        if let mode = engine.mode {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.theme.scene)
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .tracking(2)
                                    .foregroundStyle(mode.theme.primary)
                                Label(mode.title, systemImage: mode.systemImage)
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                            .padding(12)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Text("● LIVE")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(12)
                    }
            }

            content

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(resultBackdrop)
        .navigationTitle("Your Roast")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems())
        }
    }

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .writing:
            loading("Writing your bit…")
        case .voicing:
            loading("Warming up the mic…")
        case .failed(let message):
            errorView(message)
        case .ready, .idle:
            readyView
        }
    }

    private func loading(_ label: String) -> some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
            Text(label).font(.headline).foregroundStyle(.secondary)
            if !engine.script.isEmpty {
                Text(engine.script)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }

    private var readyView: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(engine.script.isEmpty ? "…" : "“\(engine.script)”")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .padding(24)
            }
            .frame(maxHeight: 260)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke((engine.mode?.theme.primary ?? .orange).opacity(0.6), lineWidth: 1.5)
            )

            HStack(spacing: 18) {
                Button {
                    engine.replay()
                } label: {
                    Image(systemName: engine.voice.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 72, height: 72)
                        .background(engine.mode?.tint ?? .orange, in: Circle())
                        .foregroundStyle(.white)
                }

                Button {
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(.white.opacity(0.12), in: Circle())
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(.white.opacity(0.12), in: Circle())
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Back") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.top, 30)
    }

    private func shareItems() -> [Any] {
        var items: [Any] = []
        if !engine.script.isEmpty {
            items.append("My Roast Machine bit: \(engine.script)")
        }
        if let audio = engine.audio {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("roast.mp3")
            try? audio.write(to: url)
            items.append(url)
        }
        return items
    }

    @ViewBuilder
    private var resultBackdrop: some View {
        ZStack {
            if let mode = engine.mode {
                ThematicBackdrop(theme: mode.theme)
                LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.85)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
        }
    }
}
