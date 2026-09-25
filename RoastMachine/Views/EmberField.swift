//
//  EmberField.swift
//  RoastMachine
//
//  Drifting glowing embers for the headliner act (and anywhere else that
//  deserves a little show business). Pure Canvas — cheap and hypnotic.
//

import SwiftUI

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
