// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

/// A small, fast, seedable pseudo-random generator, so that a game
/// started from a given seed (and the unit tests) is reproducible.
public struct SplitMix64 {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform double in [0, 1).
    public mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    public mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit()
    }

    /// A uniform integer in [0, upperBound).
    public mutating func int(_ upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }

    public mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }

    public mutating func sign() -> Int {
        chance(0.5) ? 1 : -1
    }

    public mutating func shuffle<T>(_ array: inout [T]) {
        guard array.count > 1 else { return }
        for i in stride(from: array.count - 1, to: 0, by: -1) {
            array.swapAt(i, int(i + 1))
        }
    }
}
