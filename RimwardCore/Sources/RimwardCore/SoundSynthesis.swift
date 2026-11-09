// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import Foundation

public enum SoundEffect: String, CaseIterable {
    case fire
    case hit
    case explode
    case thump
    case zap
    case death
    case overload
    case dive
    case bonus
}

/// All the game's sounds are synthesized at launch: no audio assets.
public enum SoundSynthesis {
    enum Wave {
        case square
        case saw
        case triangle
        case sine
    }

    /// Mono samples in [-1, 1].
    public static func samples(for effect: SoundEffect, sampleRate: Double = 44_100) -> [Float] {
        let sr = sampleRate
        switch effect {
        case .fire:
            return sweep(from: 1900, to: 520, duration: 0.07, wave: .square, volume: 0.16, sampleRate: sr)
        case .hit:
            return sweep(from: 900, to: 1500, duration: 0.06, wave: .triangle, volume: 0.35, sampleRate: sr)
        case .explode:
            return noise(duration: 0.34, volume: 0.5, decay: 9, smoothing: 0.5, sampleRate: sr, seed: 0x1234_5678)
        case .thump:
            return mix(noise(duration: 0.3, volume: 0.45, decay: 12, smoothing: 0.08, sampleRate: sr, seed: 0x0BAD_F00D),
                       sweep(from: 140, to: 40, duration: 0.3, wave: .sine, volume: 0.5, sampleRate: sr))
        case .zap:
            return sweep(from: 260, to: 1300, duration: 0.12, wave: .saw, volume: 0.18, sampleRate: sr)
        case .death:
            return mix(noise(duration: 1.2, volume: 0.6, decay: 2.6, smoothing: 0.3, sampleRate: sr, seed: 0xDEAD_BEEF),
                       sweep(from: 420, to: 35, duration: 1.1, wave: .square, volume: 0.22, sampleRate: sr))
        case .overload:
            return mix(sweep(from: 70, to: 1700, duration: 0.7, wave: .saw, volume: 0.24, sampleRate: sr),
                       noise(duration: 0.75, volume: 0.25, decay: 2.2, smoothing: 0.6, sampleRate: sr, seed: 0x0F0F_0F0F))
        case .dive:
            return arpeggio([392, 523.25, 659.25, 783.99, 1046.5], noteDuration: 0.09, wave: .square,
                            volume: 0.16, sampleRate: sr)
        case .bonus:
            return arpeggio([659.25, 987.77, 1318.5], noteDuration: 0.08, wave: .triangle,
                            volume: 0.3, sampleRate: sr)
        }
    }

    static func waveValue(_ wave: Wave, _ phase: Double) -> Double {
        switch wave {
        case .square: return phase < 0.5 ? 1 : -1
        case .saw: return 2 * phase - 1
        case .triangle: return 4 * abs(phase - 0.5) - 1
        case .sine: return sin(2 * Double.pi * phase)
        }
    }

    /// An exponential pitch sweep with a short attack and a decaying envelope.
    static func sweep(from f0: Double, to f1: Double, duration: Double, wave: Wave,
                      volume: Double, sampleRate: Double) -> [Float] {
        let count = max(1, Int(duration * sampleRate))
        var out = [Float](repeating: 0, count: count)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let u = Double(i) / Double(count)
            let frequency = f0 * pow(f1 / f0, u)
            phase += frequency / sampleRate
            phase -= phase.rounded(.down)
            let envelope = min(1, t / 0.004) * pow(1 - u, 1.5)
            out[i] = Float(waveValue(wave, phase) * envelope * volume)
        }
        return out
    }

    /// Exponentially decaying noise; `smoothing` in (0, 1] low-passes it
    /// (1 is white noise, small values rumble).
    static func noise(duration: Double, volume: Double, decay: Double, smoothing: Double,
                      sampleRate: Double, seed: UInt32) -> [Float] {
        let count = max(1, Int(duration * sampleRate))
        var out = [Float](repeating: 0, count: count)
        var state: UInt32 = seed == 0 ? 1 : seed
        var filtered = 0.0
        for i in 0..<count {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            let white = Double(state) / Double(UInt32.max) * 2 - 1
            filtered += (white - filtered) * smoothing
            let t = Double(i) / sampleRate
            let envelope = min(1, t / 0.003) * exp(-decay * t)
            out[i] = Float(filtered * envelope * volume)
        }
        return out
    }

    static func arpeggio(_ frequencies: [Double], noteDuration: Double, wave: Wave,
                         volume: Double, sampleRate: Double) -> [Float] {
        var out: [Float] = []
        for frequency in frequencies {
            out += sweep(from: frequency, to: frequency * 1.01, duration: noteDuration, wave: wave,
                         volume: volume, sampleRate: sampleRate)
        }
        return out
    }

    static func mix(_ a: [Float], _ b: [Float]) -> [Float] {
        var out = [Float](repeating: 0, count: max(a.count, b.count))
        for i in out.indices {
            let sum = (i < a.count ? a[i] : 0) + (i < b.count ? b[i] : 0)
            out[i] = min(1, max(-1, sum))
        }
        return out
    }
}
