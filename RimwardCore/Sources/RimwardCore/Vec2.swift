// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import Foundation

/// A 2D vector in the game's normalized view space.
///
/// The playfield fits in the square [-1, 1] x [-1, 1], y pointing up.
/// The renderer scales it to the screen.
public struct Vec2: Equatable, Hashable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }
    public static prefix func - (a: Vec2) -> Vec2 { Vec2(-a.x, -a.y) }

    public var length: Double { (x * x + y * y).squareRoot() }

    public var normalized: Vec2 {
        let l = length
        return l > 1e-12 ? self * (1 / l) : .zero
    }

    /// The vector rotated a quarter turn counter-clockwise.
    public var perpendicular: Vec2 { Vec2(-y, x) }

    public func dot(_ other: Vec2) -> Double { x * other.x + y * other.y }

    public func rotated(by angle: Double) -> Vec2 {
        let c = cos(angle), s = sin(angle)
        return Vec2(x * c - y * s, x * s + y * c)
    }

    public static func lerp(_ a: Vec2, _ b: Vec2, _ t: Double) -> Vec2 { a + (b - a) * t }
}
