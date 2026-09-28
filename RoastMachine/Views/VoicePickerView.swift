//
//  VoicePickerView.swift
//  RoastMachine
//
//  Pick who delivers the bit. The choice is per flavor: one voice for roasts,
//  one for hype. Tapping a card selects it and plays a sample.
//

import SwiftUI

struct VoicePickerView: View {
    let flavor: RoastFlavor
    @Binding var selectedID: String
    let voice: VoiceService
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { flavor == .compliment ? .pink : .orange }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text("🎙️").font(.system(size: 48))
                        Text("PICK A VOICE")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .tracking(1)
                        Text(flavor == .compliment ? "Who hypes you up?" : "Who roasts you?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                              spacing: 12) {
                        ForEach(Voice.all) { v in
                            card(v)
                        }
                    }

                    Text("Tap a voice to hear it. Every comedian speaks in the voice you pick.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .background(
                LinearGradient(colors: [.black, Color(red: 0.2, green: 0.07, blue: 0.2), .black],
                               startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            )
            .navigationTitle(flavor == .compliment ? "Hype Voice" : "Roast Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func card(_ v: Voice) -> some View {
        let selected = v.id == selectedID
        return Button {
            Haptics.tap(.medium)
            selectedID = v.id
            Task { await voice.previewVoice(v, flavor: flavor) }
        } label: {
            VStack(spacing: 6) {
                Text(v.emoji).font(.system(size: 40))
                Text(v.name)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Text(v.vibe)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Image(systemName: voice.previewingID == v.id ? "speaker.wave.3.fill" : "play.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent)
                    .padding(.top, 2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.white.opacity(selected ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selected ? accent : .white.opacity(0.12), lineWidth: selected ? 3 : 1)
            )
            .shadow(color: selected ? accent.opacity(0.6) : .clear, radius: 10)
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(accent)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
