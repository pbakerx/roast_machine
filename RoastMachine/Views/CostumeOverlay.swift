//
//  CostumeOverlay.swift
//  RoastMachine
//
//  Face-anchored costume overlays. Wearable props (AI-generated, chroma-keyed
//  to transparency) snap onto slots of the face-guide rect — hat on the head,
//  glasses on the eyes, mustache on the mouth, chain on the neck — like a
//  photo booth that heckles you. Plus the drifting stage embers.
//

import SwiftUI

// MARK: - Wearable overlay

/// Draws transparent costume props anchored to the face guide. Layout mirrors
/// FaceGuideOverlay: guide is 72% of width, 1.25 aspect, centered at 40% height.
struct WearableOverlayView: View {
    let images: [WearableSlot: UIImage]
    /// Slots allowed to show right now (drives the timed reveal in ResultView).
    /// Nil means show everything available.
    var revealed: Set<WearableSlot>? = nil

    var body: some View {
        GeometryReader { geo in
            let gw = geo.size.width * 0.72
            let gh = gw * 1.25
            let cx = geo.size.width / 2
            let topY = geo.size.height * 0.40 - gh / 2
            let bottomY = geo.size.height * 0.40 + gh / 2

            ForEach(Array(visibleSlots.enumerated()), id: \.element.rawValue) { index, slot in
                if let ui = images[slot] {
                    let w = gw * widthFraction(slot)
                    let h = w * ui.size.height / ui.size.width
                    WearablePop(image: ui, delay: Double(index) * 0.1)
                        .frame(width: w, height: h)
                        .position(x: cx, y: yPosition(slot, pieceHeight: h,
                                                      topY: topY, bottomY: bottomY, gh: gh))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var visibleSlots: [WearableSlot] {
        WearableSlot.revealOrder.filter { slot in
            images[slot] != nil && (revealed?.contains(slot) ?? true)
        }
    }

    private func widthFraction(_ slot: WearableSlot) -> CGFloat {
        switch slot {
        case .head:  return 0.95
        case .eyes:  return 0.8
        case .mouth: return 0.62
        case .neck:  return 0.95
        }
    }

    private func yPosition(_ slot: WearableSlot, pieceHeight: CGFloat,
                           topY: CGFloat, bottomY: CGFloat, gh: CGFloat) -> CGFloat {
        switch slot {
        case .head:  return topY - pieceHeight / 2 + pieceHeight * 0.30
        case .eyes:  return topY + gh * 0.34
        case .mouth: return topY + gh * 0.62
        case .neck:  return bottomY + pieceHeight * 0.10
        }
    }
}

/// One prop snapping on with a goofy overshoot wobble.
private struct WearablePop: View {
    let image: UIImage
    let delay: Double
    @State private var shown = false

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            .scaleEffect(shown ? 1 : 0.2)
            .rotationEffect(.degrees(shown ? 0 : -18))
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(delay)) {
                    shown = true
                }
            }
    }
}

// MARK: - Stage flair

/// Drifting glowing embers for the headliner act (and anywhere else that
/// deserves a little show business). Pure Canvas — cheap and hypnotic.
struct EmberField: View {
    var tint: Color = .orange
    var count: Int = 22

    private struct Ember {
        let x: Double        // 0..1 horizontal home
        let speed: Double    // vertical loops per minute-ish
        let drift: Double    // horizontal sway amplitude
        let size: Double
        let phase: Double
    }

    private var embers: [Ember] {
        var rng = SeededRandom(seed: 0xF1AE)
        return (0..<count).map { _ in
            Ember(x: rng.next(),
                  speed: 0.35 + rng.next() * 0.8,
                  drift: 0.02 + rng.next() * 0.05,
                  size: 2.5 + rng.next() * 5,
                  phase: rng.next())
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for ember in embers {
                    let progress = (t * ember.speed / 10 + ember.phase)
                        .truncatingRemainder(dividingBy: 1)
                    let y = size.height * (1.05 - progress * 1.15)
                    let x = size.width * (ember.x + sin(t * 0.9 + ember.phase * 7) * ember.drift)
                    let fade = sin(progress * .pi)  // in low, out high
                    let rect = CGRect(x: x, y: y, width: ember.size, height: ember.size)
                    context.opacity = fade * 0.85
                    context.addFilter(.blur(radius: 0.8))
                    context.fill(Path(ellipseIn: rect), with: .color(tint))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Tiny deterministic PRNG so the ember field is stable between renders.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xBAD5EED : seed }
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 100_000) / 100_000
    }
}
