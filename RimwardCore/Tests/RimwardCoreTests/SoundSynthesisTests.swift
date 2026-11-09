// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import XCTest
@testable import RimwardCore

final class SoundSynthesisTests: XCTestCase {
    func testEveryEffectIsAudibleAndInRange() {
        for effect in SoundEffect.allCases {
            let samples = SoundSynthesis.samples(for: effect)
            XCTAssertGreaterThan(samples.count, 1000, effect.rawValue)
            XCTAssertLessThan(samples.count, 44_100 * 2, effect.rawValue)
            XCTAssertTrue(samples.allSatisfy { $0 >= -1 && $0 <= 1 && $0.isFinite }, effect.rawValue)
            XCTAssertGreaterThan(samples.map { abs($0) }.max() ?? 0, 0.05, effect.rawValue)
        }
    }
}
