//
//  StageComponents.swift
//  RoastMachine
//
//  The tactile, mechanical UI kit for the Stage: brushed-metal panels, a knurled
//  mode dial, a chunky shutter, and the themed face-positioning overlay.
//

import SwiftUI
import UIKit

// MARK: - Haptics

enum Haptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func thunk() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

// MARK: - Metal surfaces

enum Metal {
    static let steel = LinearGradient(
        colors: [Color(white: 0.34), Color(white: 0.16), Color(white: 0.10), Color(white: 0.22)],
        startPoint: .top, endPoint: .bottom
    )
    static func knob(_ tint: Color) -> RadialGradient {
        RadialGradient(
            colors: [Color(white: 0.46), Color(white: 0.20), Color(white: 0.12)],
            center: .init(x: 0.4, y: 0.35), startRadius: 1, endRadius: 40
        )
    }
}

/// A brushed-metal panel with a bevel edge and corner rivets.
struct MetalPanel: View {
    var cornerRadius: CGFloat = 26
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Metal.steel)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.45), .clear, .black.opacity(0.5)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5
                )
            rivets
        }
    }
    private var rivets: some View {
        GeometryReader { geo in
            let inset: CGFloat = 16
            ForEach(0..<4, id: \.self) { i in
                let x = (i % 2 == 0) ? inset : geo.size.width - inset
                let y = (i < 2) ? inset : geo.size.height - inset
                Rivet().position(x: x, y: y)
            }
        }
    }
}

struct Rivet: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(white: 0.55), Color(white: 0.12)],
                                 center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 6))
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 0.5))
    }
}

// MARK: - Knurled mode dial

struct KnurlRing: View {
    var ticks: Int = 44
    var body: some View {
        ZStack {
            ForEach(0..<ticks, id: \.self) { i in
                Capsule()
                    .fill(.black.opacity(0.35))
                    .frame(width: 1.5, height: 6)
                    .offset(y: -27)
                    .rotationEffect(.degrees(Double(i) / Double(ticks) * 360))
            }
        }
    }
}

struct ModeKnob: View {
    let symbol: String
    let tint: Color
    let selected: Bool
    let locked: Bool

    var body: some View {
        ZStack {
            Circle().fill(Metal.knob(tint))
            KnurlRing()
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.28), Color(white: 0.10)],
                                     center: .center, startRadius: 1, endRadius: 26))
                .padding(10)
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selected ? tint : Color(white: 0.72))
                .shadow(color: selected ? tint.opacity(0.8) : .clear, radius: 6)

            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.yellow)
                    .padding(3)
                    .background(.black.opacity(0.6), in: Circle())
                    .offset(x: 18, y: -18)
            }
        }
        .frame(width: 64, height: 64)
        .overlay(
            Circle().stroke(selected ? tint : .black.opacity(0.6),
                            lineWidth: selected ? 3 : 1)
        )
        .shadow(color: selected ? tint.opacity(0.6) : .black.opacity(0.6),
                radius: selected ? 12 : 4, y: 3)
        .scaleEffect(selected ? 1.14 : 0.86)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }
}

struct ModeDial: View {
    let modes: [RoastMode]
    @Binding var selectedID: String
    var isLocked: (RoastMode) -> Bool
    var onSelect: (RoastMode) -> Void
    /// Speaks a short sample in the mode's voice. Nil hides the preview buttons.
    var onPreview: ((RoastMode) -> Void)? = nil
    var previewingID: String? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(modes) { mode in
                        knobCell(mode, proxy: proxy)
                            .id(mode.id)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 8)
            }
            .onAppear {
                proxy.scrollTo(selectedID, anchor: .center)
            }
        }
    }

    private func knobCell(_ mode: RoastMode, proxy: ScrollViewProxy) -> some View {
        Button {
            Haptics.tap(.medium)
            onSelect(mode)
            withAnimation { proxy.scrollTo(mode.id, anchor: .center) }
        } label: {
            ModeKnob(symbol: mode.systemImage,
                     tint: mode.theme.primary,
                     selected: mode.id == selectedID,
                     locked: isLocked(mode))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if let onPreview {
                Button {
                    Haptics.tap()
                    onPreview(mode)
                } label: {
                    Group {
                        if previewingID == mode.id {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                        } else {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 20, height: 20)
                    .background(mode.theme.primary.opacity(0.9), in: Circle())
                    .overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: 4)
                .disabled(previewingID != nil)
            }
        }
    }
}

// MARK: - Shutter

struct ShutterButton: View {
    let tint: Color
    var action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            Haptics.thunk()
            action()
        } label: {
            ZStack {
                Circle().fill(Metal.knob(tint)).frame(width: 84, height: 84)
                Circle().stroke(.black.opacity(0.6), lineWidth: 2).frame(width: 84, height: 84)
                Circle()
                    .fill(RadialGradient(colors: [tint, tint.opacity(0.65)],
                                         center: .init(x: 0.4, y: 0.35), startRadius: 2, endRadius: 40))
                    .frame(width: 60, height: 60)
                    .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                    .shadow(color: tint.opacity(0.8), radius: pressed ? 4 : 14)
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .scaleEffect(pressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - Scene backdrop + scrims

struct ThematicBackdrop: View {
    let theme: ModeTheme

    var body: some View {
        Group {
            if let name = theme.imageName, UIImage(named: name) != nil {
                GeometryReader { geo in
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            } else {
                procedural
            }
        }
        .ignoresSafeArea()
    }

    /// Original gradient-and-motifs look, kept as a fallback for modes
    /// without painted art.
    private var procedural: some View {
        ZStack {
            LinearGradient(colors: theme.backdrop, startPoint: .top, endPoint: .bottom)
            GeometryReader { geo in
                ForEach(0..<10, id: \.self) { i in
                    Image(systemName: theme.motifs[i % theme.motifs.count])
                        .font(.system(size: [30.0, 46, 62][i % 3]))
                        .foregroundStyle(theme.primary.opacity(0.10))
                        .position(
                            x: geo.size.width * [0.15, 0.8, 0.5, 0.28, 0.92, 0.65, 0.08, 0.45, 0.72, 0.35][i],
                            y: geo.size.height * [0.12, 0.2, 0.35, 0.55, 0.5, 0.72, 0.85, 0.9, 0.62, 0.28][i]
                        )
                }
            }
        }
    }
}

/// Darkens top and bottom so the mechanical chrome and title read over the camera.
struct SceneScrim: View {
    let theme: ModeTheme
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.75), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
            Spacer()
            LinearGradient(colors: [.clear, theme.backdrop.first?.opacity(0.5) ?? .black.opacity(0.5), .black.opacity(0.92)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 300)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Face positioning overlay

struct FaceGuideOverlay: View {
    let theme: ModeTheme
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.72
            let h = w * 1.25
            let cx = geo.size.width / 2
            let cy = geo.size.height * 0.40

            ZStack {
                GuideOutline(shape: theme.guide)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: dash))
                    .foregroundStyle(theme.primary.opacity(0.9))
                    .shadow(color: theme.primary.opacity(0.7), radius: 8)

                if theme.guide == .plate {
                    GuideOutline(shape: .plate)
                        .stroke(theme.secondary.opacity(0.6), lineWidth: 1.5)
                        .scaleEffect(0.82)
                }
                if theme.guide == .frame {
                    CornerBrackets()
                        .stroke(theme.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
            }
            .frame(width: w, height: h)
            .position(x: cx, y: cy)
            .scaleEffect(pulse ? 1.02 : 0.98)
            .opacity(pulse ? 1 : 0.75)
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

            hintPill
                .position(x: cx, y: cy + h / 2 + 34)
        }
        .allowsHitTesting(false)
        .onAppear { pulse = true }
    }

    private var dash: [CGFloat] {
        switch theme.guide {
        case .frame, .diamond: return [10, 8]
        default: return [4, 10]
        }
    }

    private var hintPill: some View {
        Text(theme.hint)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(theme.primary.opacity(0.8), lineWidth: 1.5))
    }
}

/// The outline path used by the face guide, per scene.
struct GuideOutline: Shape {
    let shape: ModeTheme.GuideShape

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch shape {
        case .oval, .spotlight:
            p.addEllipse(in: rect)
        case .plate:
            let d = min(rect.width, rect.height)
            let r = CGRect(x: rect.midX - d/2, y: rect.midY - d/2, width: d, height: d)
            p.addEllipse(in: r)
        case .frame:
            p.addRoundedRect(in: rect, cornerSize: CGSize(width: 24, height: 24))
        case .diamond:
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
        }
        return p
    }
}

/// Four L-shaped corner brackets (used by the "frame" guide).
struct CornerBrackets: Shape {
    var len: CGFloat = 30
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len)); p.addLine(to: CGPoint(x: rect.minX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        // bottom-left
        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        return p
    }
}
