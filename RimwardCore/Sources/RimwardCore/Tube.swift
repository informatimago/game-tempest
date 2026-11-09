// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import Foundation

/// Euclidean modulo: the result is always in [0, n).
@inline(__always)
func wrapIndex(_ a: Int, _ n: Int) -> Int {
    let r = a % n
    return r < 0 ? r + n : r
}

/// A frame local to one lane at one depth: the origin is the lane center,
/// `xAxis` spans the lane from edge to edge, `yAxis` has the same length
/// and points away from the vanishing point (outward, toward the player).
public struct LocalFrame: Equatable {
    public var origin: Vec2
    public var xAxis: Vec2
    public var yAxis: Vec2

    public func map(_ p: Vec2) -> Vec2 {
        origin + xAxis * p.x + yAxis * p.y
    }
}

/// The well the game is played in.
///
/// The near end (the rim, depth 1) is a polyline of `rim` points, closed or
/// open. Every rim point recedes toward `vanishingPoint` as depth goes to 0,
/// with a perspective that shrinks the far end to `farScale`.
/// Lane `i` lies between edge `i` and edge `i + 1`.
public struct Tube: Equatable {
    public let name: String
    public let rim: [Vec2]
    public let isClosed: Bool
    public let vanishingPoint: Vec2
    public let farScale: Double

    public init(name: String, rim: [Vec2], isClosed: Bool, vanishingPoint: Vec2, farScale: Double) {
        precondition(rim.count >= (isClosed ? 3 : 2), "a tube needs at least one lane")
        precondition(farScale > 0 && farScale < 1)
        self.name = name
        self.rim = rim
        self.isClosed = isClosed
        self.vanishingPoint = vanishingPoint
        self.farScale = farScale
    }

    public var laneCount: Int { isClosed ? rim.count : rim.count - 1 }

    /// The perspective scale of a cross-section at `depth`
    /// (1 at the rim, `farScale` at the far end).
    public func depthScale(_ depth: Double) -> Double {
        let zFar = 1.0 / farScale
        let z = zFar - (zFar - 1.0) * depth
        return 1.0 / z
    }

    public func project(_ rimPoint: Vec2, depth: Double) -> Vec2 {
        vanishingPoint + (rimPoint - vanishingPoint) * depthScale(depth)
    }

    func edgeIndex(_ i: Int) -> Int {
        isClosed ? wrapIndex(i, rim.count) : min(max(i, 0), rim.count - 1)
    }

    public func edgePoint(_ index: Int, depth: Double) -> Vec2 {
        project(rim[edgeIndex(index)], depth: depth)
    }

    /// The canonical index of `lane`, or nil when it falls off an open tube.
    public func normalizedLane(_ lane: Int) -> Int? {
        if isClosed { return wrapIndex(lane, laneCount) }
        return (0..<laneCount).contains(lane) ? lane : nil
    }

    /// A point at a continuous position across the lanes, in edge units:
    /// lane `L` spans [L, L + 1] and its center is at `L + 0.5`.
    public func point(at position: Double, depth: Double) -> Vec2 {
        let base = Int(position.rounded(.down))
        let f = position - Double(base)
        return Vec2.lerp(edgePoint(base, depth: depth), edgePoint(base + 1, depth: depth), f)
    }

    public func laneCenter(_ lane: Int, depth: Double) -> Vec2 {
        point(at: Double(lane) + 0.5, depth: depth)
    }

    public func frame(at position: Double, depth: Double) -> LocalFrame {
        let lane = Int(position.rounded(.down))
        let across = edgePoint(lane + 1, depth: depth) - edgePoint(lane, depth: depth)
        let center = point(at: position, depth: depth)
        var outward = across.perpendicular
        if outward.dot(center - vanishingPoint) < 0 { outward = -outward }
        return LocalFrame(origin: center, xAxis: across, yAxis: outward)
    }

    /// The signed number of single-lane steps to go from lane `a` to lane `b`
    /// (the shortest way round on a closed tube).
    public func laneSteps(from a: Int, to b: Int) -> Int {
        guard isClosed else { return b - a }
        var d = wrapIndex(b - a, laneCount)
        if d > laneCount / 2 { d -= laneCount }
        return d
    }

    /// Distance between two continuous positions, wrapping on a closed tube.
    public func positionDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b)
        guard isClosed else { return d }
        let n = Double(laneCount)
        let m = d.truncatingRemainder(dividingBy: n)
        return min(m, n - m)
    }

    /// The lane whose rim center lies in the direction of `aim`, as seen from
    /// the vanishing point. This is how a finger anywhere on the screen
    /// steers the ship. Nil when `aim` is too close to the vanishing point.
    public func nearestLane(toward aim: Vec2) -> Int? {
        let offset = aim - vanishingPoint
        guard offset.length > 0.04 else { return nil }
        let direction = offset.normalized
        var best = 0
        var bestScore = -Double.infinity
        for lane in 0..<laneCount {
            let score = (laneCenter(lane, depth: 1) - vanishingPoint).normalized.dot(direction)
            if score > bestScore {
                bestScore = score
                best = lane
            }
        }
        return best
    }
}
