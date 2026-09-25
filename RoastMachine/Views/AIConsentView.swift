//
//  AIConsentView.swift
//  RoastMachine
//
//  One-time "before the show" card: says plainly that the photo goes to
//  OpenAI and the words go to ElevenLabs, and asks before anything is sent.
//  App Review guideline 5.1.2(i) requires explicit permission before sharing
//  personal data with third-party AI.
//

import SwiftUI

struct AIConsentView: View {
    var onAgree: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            Text("🎤")
                .font(.system(size: 64))

            Text("BEFORE THE SHOW")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .tracking(2)

            VStack(alignment: .leading, spacing: 16) {
                row("photo.fill", "Your photo goes to **OpenAI**, whose AI writes the bit.")
                row("waveform", "The words go to **ElevenLabs**, whose AI gives them a voice.")
                row("hand.raised.fill", "We don't keep either. No account, no tracking.")
                row("theatermasks.fill", "It's AI comedy. Use your own photo, or a friend who's in on it.")
            }
            .padding(20)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))

            Button {
                Haptics.thunk()
                onAgree()
                dismiss()
            } label: {
                Text("LET'S GO 🔥")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: [.orange, .red],
                                       startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                    .shadow(color: .orange.opacity(0.6), radius: 12, y: 4)
            }

            HStack(spacing: 24) {
                Button("Not now") { dismiss() }
                Link("Privacy & AI Policy", destination: AppConfig.privacyPolicyURL)
            }
            .font(.subheadline)
            .tint(.white.opacity(0.7))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [.black, Color(red: 0.24, green: 0.08, blue: 0.22)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .presentationDetents([.large])
    }

    private func row(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.orange)
                .frame(width: 26)
            Text(text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
