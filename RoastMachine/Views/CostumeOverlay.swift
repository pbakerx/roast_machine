//
//  CostumeOverlay.swift
//  RoastMachine
//
//  Per-mode costume graphics worn over the live selfie: a chef gets a toque
//  and coat, the bard gets a plumed cap and ruff, the conspiracy theorist gets
//  the tinfoil. Pieces anchor to the same rect as the face-positioning guide,
//  so when your face is in the guide, the costume fits.
//

import SwiftUI

// MARK: - Catalog

struct CostumePiece {
    enum Slot { case head, eyes, neck }

    let asset: String
    let slot: Slot
    /// Width relative to the face-guide width.
    let widthFraction: CGFloat

    static func pieces(for modeID: String) -> [CostumePiece] {
        func head(_ w: CGFloat = 0.9) -> CostumePiece {
            CostumePiece(asset: "costume_\(modeID)_head", slot: .head, widthFraction: w)
        }
        func eyes(_ w: CGFloat = 0.8) -> CostumePiece {
            CostumePiece(asset: "costume_\(modeID)_eyes", slot: .eyes, widthFraction: w)
        }
        func neck(_ w: CGFloat = 0.95) -> CostumePiece {
            CostumePiece(asset: "costume_\(modeID)_neck", slot: .neck, widthFraction: w)
        }
        switch modeID {
        case "classic":     return [head(0.85), neck(0.55)]
        case "nature":      return [head(1.0)]
        case "ramsay":      return [head(0.8), neck(1.05)]
        case "mom":         return [head(0.85), neck(0.75)]
        case "shakespeare": return [head(0.9), neck(1.0)]
        case "disstrack":   return [head(0.85), neck(0.8)]
        case "beautiful":   return [head(0.8)]
        case "fortune":     return [head(0.85)]
        case "drill":       return [head(1.0)]
        case "linkedin":    return [neck(0.9)]
        case "conspiracy":  return [head(0.75)]
        case "pickup":      return [neck(1.0)]
        case "datingbio":   return [eyes(0.85)]
        case "pet":         return [head(0.8), neck(0.7)]
        default:            return []
        }
    }
}

// MARK: - Overlay view

/// Draws the selected mode's costume pieces anchored to the face guide rect.
/// Layout mirrors FaceGuideOverlay: guide is 72% of width, 1.25 aspect,
/// centered at 40% height.
struct CostumeOverlayView: View {
    let modeID: String

    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let gw = geo.size.width * 0.72
            let gh = gw * 1.25
            let cx = geo.size.width / 2
            let topY = geo.size.height * 0.40 - gh / 2
            let bottomY = geo.size.height * 0.40 + gh / 2

            ForEach(Array(CostumePiece.pieces(for: modeID).enumerated()), id: \.element.asset) { index, piece in
                if let ui = UIImage(named: piece.asset) {
                    let w = gw * piece.widthFraction
                    let h = w * ui.size.height / ui.size.width
                    Image(uiImage: ui)
                        .resizable()
                        .frame(width: w, height: h)
                        .position(x: cx, y: yPosition(for: piece.slot,
                                                      pieceHeight: h,
                                                      topY: topY, bottomY: bottomY,
                                                      guideHeight: gh))
                        .scaleEffect(shown ? 1 : 0.3)
                        .rotationEffect(.degrees(shown ? 0 : (index.isMultiple(of: 2) ? -14 : 14)))
                        .opacity(shown ? 1 : 0)
                        .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(Double(index) * 0.08),
                                   value: shown)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { shown = true }
        .onChange(of: modeID) { _, _ in
            shown = false
            withAnimation { shown = true }
        }
    }

    private func yPosition(for slot: CostumePiece.Slot, pieceHeight: CGFloat,
                           topY: CGFloat, bottomY: CGFloat, guideHeight: CGFloat) -> CGFloat {
        switch slot {
        case .head:
            // brim overlaps the top of the guide slightly
            return topY - pieceHeight / 2 + pieceHeight * 0.22
        case .eyes:
            return topY + guideHeight * 0.34
        case .neck:
            return bottomY + pieceHeight * 0.18
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
