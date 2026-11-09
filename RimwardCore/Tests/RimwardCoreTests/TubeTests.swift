// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import XCTest
@testable import RimwardCore

final class TubeTests: XCTestCase {
    func testEveryTubeIsPlayableAndFitsTheView() {
        for index in 0..<TubeCatalog.count {
            let tube = TubeCatalog.tube(index: index)
            XCTAssertGreaterThanOrEqual(tube.laneCount, 12, tube.name)
            XCTAssertLessThanOrEqual(tube.laneCount, 20, tube.name)
            for p in tube.rim {
                XCTAssertLessThanOrEqual(abs(p.x), 1.0, tube.name)
                XCTAssertLessThanOrEqual(abs(p.y), 1.0, tube.name)
            }
        }
    }

    func testTubesHaveDistinctNames() {
        let names = Set((0..<TubeCatalog.count).map { TubeCatalog.tube(index: $0).name })
        XCTAssertEqual(names.count, TubeCatalog.count)
    }

    func testLevelsCycleThroughTheCatalog() {
        XCTAssertEqual(TubeCatalog.tube(forLevel: 1), TubeCatalog.tube(index: 0))
        XCTAssertEqual(TubeCatalog.tube(forLevel: TubeCatalog.count + 1), TubeCatalog.tube(index: 0))
        XCTAssertEqual(TubeCatalog.tube(forLevel: 2), TubeCatalog.tube(index: 1))
    }

    func testResampledRingHasEqualLanes() {
        let ring = TubeCatalog.tube(index: 0)
        let widths = (0..<ring.laneCount).map { (ring.edgePoint($0 + 1, depth: 1) - ring.edgePoint($0, depth: 1)).length }
        let mean = widths.reduce(0, +) / Double(widths.count)
        for w in widths { XCTAssertEqual(w, mean, accuracy: mean * 0.02) }
    }

    func testDepthScaleGoesFromFarScaleToOne() {
        let tube = TubeCatalog.tube(index: 0)
        XCTAssertEqual(tube.depthScale(1), 1, accuracy: 1e-12)
        XCTAssertEqual(tube.depthScale(0), tube.farScale, accuracy: 1e-12)
        var previous = tube.depthScale(0)
        for k in 1...20 {
            let s = tube.depthScale(Double(k) / 20)
            XCTAssertGreaterThan(s, previous)
            previous = s
        }
    }

    func testLaneStepsTakeTheShortWayRound() {
        let ring = TubeCatalog.tube(index: 0)
        XCTAssertEqual(ring.laneCount, 16)
        XCTAssertEqual(ring.laneSteps(from: 15, to: 0), 1)
        XCTAssertEqual(ring.laneSteps(from: 0, to: 15), -1)
        XCTAssertEqual(ring.laneSteps(from: 2, to: 5), 3)
        let ribbon = TubeCatalog.tube(index: 6)
        XCTAssertFalse(ribbon.isClosed)
        XCTAssertEqual(ribbon.laneSteps(from: 13, to: 0), -13)
        XCTAssertNil(ribbon.normalizedLane(-1))
        XCTAssertNil(ribbon.normalizedLane(ribbon.laneCount))
    }

    func testAimingDownSelectsTheBottomLane() {
        let ring = TubeCatalog.tube(index: 0)
        let lane = ring.nearestLane(toward: Vec2(0, -1.5))
        XCTAssertNotNil(lane)
        XCTAssertLessThan(ring.laneCenter(lane!, depth: 1).y, -0.8)
        XCTAssertNil(ring.nearestLane(toward: ring.vanishingPoint))
    }

    func testLocalFramePointsOutward() {
        for index in 0..<TubeCatalog.count {
            let tube = TubeCatalog.tube(index: index)
            for lane in 0..<tube.laneCount {
                let frame = tube.frame(at: Double(lane) + 0.5, depth: 1)
                XCTAssertGreaterThan(frame.yAxis.dot(frame.origin - tube.vanishingPoint), 0, tube.name)
            }
        }
    }
}
