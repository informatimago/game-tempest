// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import Foundation

/// The wells, one per level, cycling. All are generated procedurally.
public enum TubeCatalog {
    public static let count = 12

    public static func tube(forLevel level: Int) -> Tube {
        tube(index: (max(level, 1) - 1) % count)
    }

    public static func tube(index: Int) -> Tube {
        let tau = 2 * Double.pi
        switch wrapIndex(index, count) {
        case 0:
            return Tube(name: "Ring",
                        rim: resample(points: 16, closed: true) { t in
                            Vec2(0.88 * cos(-Double.pi / 2 + tau * t), 0.88 * sin(-Double.pi / 2 + tau * t))
                        },
                        isClosed: true, vanishingPoint: .zero, farScale: 0.16)
        case 1:
            return Tube(name: "Hexagon",
                        rim: subdivide(regular(sides: 6, radius: 0.9, rotation: -Double.pi / 2), perSide: 3, closed: true),
                        isClosed: true, vanishingPoint: .zero, farScale: 0.15)
        case 2:
            return Tube(name: "Bloom",
                        rim: resample(points: 20, closed: true) { t in
                            let a = -Double.pi / 2 + tau * t
                            let r = 0.74 + 0.16 * cos(5 * (a + Double.pi / 2))
                            return Vec2(r * cos(a), r * sin(a))
                        },
                        isClosed: true, vanishingPoint: .zero, farScale: 0.14)
        case 3:
            return Tube(name: "Pentagon",
                        rim: subdivide(regular(sides: 5, radius: 0.92, rotation: Double.pi / 2), perSide: 3, closed: true),
                        isClosed: true, vanishingPoint: Vec2(0, -0.06), farScale: 0.15)
        case 4:
            return Tube(name: "Trough",
                        rim: resample(points: 15, closed: false) { t in
                            let a = Double.pi * (1.06 + 0.88 * t)
                            return Vec2(0.95 * cos(a), 0.25 + 0.95 * sin(a))
                        },
                        isClosed: false, vanishingPoint: Vec2(0, 0.38), farScale: 0.22)
        case 5:
            var star: [Vec2] = []
            for k in 0..<10 {
                let a = Double.pi / 2 + Double(k) * Double.pi / 5
                let r = k % 2 == 0 ? 0.93 : 0.47
                star.append(Vec2(r * cos(a), r * sin(a)))
            }
            return Tube(name: "Star", rim: subdivide(star, perSide: 2, closed: true),
                        isClosed: true, vanishingPoint: .zero, farScale: 0.13)
        case 6:
            return Tube(name: "Ribbon",
                        rim: resample(points: 15, closed: false) { t in
                            let x = -0.95 + 1.9 * t
                            return Vec2(x, -0.45 + 0.12 * sin(3 * Double.pi * x))
                        },
                        isClosed: false, vanishingPoint: Vec2(0, 0.62), farScale: 0.25)
        case 7:
            return Tube(name: "Diamond",
                        rim: subdivide(regular(sides: 4, radius: 0.93, rotation: -Double.pi / 2), perSide: 4, closed: true),
                        isClosed: true, vanishingPoint: .zero, farScale: 0.15)
        case 8:
            return Tube(name: "Chevron",
                        rim: subdivide([Vec2(-0.95, 0.15), Vec2(0, -0.72), Vec2(0.95, 0.15)], perSide: 7, closed: false),
                        isClosed: false, vanishingPoint: Vec2(0, 0.55), farScale: 0.22)
        case 9:
            return Tube(name: "Oval",
                        rim: resample(points: 16, closed: true) { t in
                            let a = -Double.pi / 2 + tau * t
                            return Vec2(0.95 * cos(a), 0.62 * sin(a))
                        },
                        isClosed: true, vanishingPoint: Vec2(0, 0.05), farScale: 0.15)
        case 10:
            return Tube(name: "Horseshoe",
                        rim: resample(points: 17, closed: false) { t in
                            let a = Double.pi / 2 + 0.5 + (tau - 1.0) * t
                            return Vec2(0.88 * cos(a), 0.88 * sin(a))
                        },
                        isClosed: false, vanishingPoint: .zero, farScale: 0.16)
        default:
            var zigzag: [Vec2] = []
            for k in 0...7 {
                zigzag.append(Vec2(-0.95 + 1.9 * Double(k) / 7, k % 2 == 0 ? -0.36 : -0.62))
            }
            return Tube(name: "Zigzag", rim: subdivide(zigzag, perSide: 2, closed: false),
                        isClosed: false, vanishingPoint: Vec2(0, 0.52), farScale: 0.25)
        }
    }

    // MARK: - Shape construction

    /// Samples the parametric curve `f` on [0, 1] and returns `points` points
    /// equally spaced along its length (the last point is the end of the curve
    /// for an open curve; for a closed one, the curve is assumed to come back
    /// to its start at t = 1).
    static func resample(points n: Int, closed: Bool, _ f: (Double) -> Vec2) -> [Vec2] {
        let samples = 2048
        var pts: [Vec2] = []
        pts.reserveCapacity(samples + 1)
        for i in 0...samples { pts.append(f(Double(i) / Double(samples))) }
        var cumulative: [Double] = [0]
        cumulative.reserveCapacity(samples + 1)
        for i in 1...samples { cumulative.append(cumulative[i - 1] + (pts[i] - pts[i - 1]).length) }
        let total = cumulative[samples]
        let divisions = Double(closed ? n : n - 1)
        var result: [Vec2] = []
        var seg = 1
        for k in 0..<n {
            let target = total * Double(k) / divisions
            while seg < samples && cumulative[seg] < target { seg += 1 }
            let l0 = cumulative[seg - 1], l1 = cumulative[seg]
            let t = l1 > l0 ? min(max((target - l0) / (l1 - l0), 0), 1) : 0
            result.append(Vec2.lerp(pts[seg - 1], pts[seg], t))
        }
        return result
    }

    static func regular(sides: Int, radius: Double, rotation: Double) -> [Vec2] {
        (0..<sides).map { k in
            let a = rotation + 2 * Double.pi * Double(k) / Double(sides)
            return Vec2(radius * cos(a), radius * sin(a))
        }
    }

    /// Splits each side of a polygon (or polyline) into `perSide` equal lanes.
    static func subdivide(_ vertices: [Vec2], perSide: Int, closed: Bool) -> [Vec2] {
        var out: [Vec2] = []
        let sides = closed ? vertices.count : vertices.count - 1
        for s in 0..<sides {
            let a = vertices[s], b = vertices[(s + 1) % vertices.count]
            for k in 0..<perSide {
                out.append(Vec2.lerp(a, b, Double(k) / Double(perSide)))
            }
        }
        if !closed, let last = vertices.last { out.append(last) }
        return out
    }
}
