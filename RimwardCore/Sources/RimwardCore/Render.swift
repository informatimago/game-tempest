// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import Foundation

/// Logical colours; the host maps them to its own palette.
public enum ColorTag: Int, CaseIterable, Equatable {
    case tube
    case laneHighlight
    case player
    case shot
    case skitter
    case brood
    case sower
    case orbiter
    case orbiterShield
    case lancer
    case bolt
    case mine

    static func forEnemy(_ kind: EnemyKind) -> ColorTag {
        switch kind {
        case .skitter: return .skitter
        case .brood: return .brood
        case .sower: return .sower
        case .orbiter: return .orbiter
        case .lancer: return .lancer
        }
    }
}

/// One polyline to draw, in view space ([-1, 1] square, y up).
public struct Stroke: Equatable {
    public var points: [Vec2]
    public var closed: Bool
    public var color: ColorTag

    public init(points: [Vec2], closed: Bool, color: ColorTag) {
        self.points = points
        self.closed = closed
        self.color = color
    }
}

/// The vector shapes, in lane-local coordinates: x across the lane
/// (one unit = the lane width), y outward toward the rim.
enum Glyphs {
    static let player: [Vec2] = [
        Vec2(-0.5, 0.05), Vec2(-0.34, 0.34), Vec2(-0.18, 0.08), Vec2(0, 0.3),
        Vec2(0.18, 0.08), Vec2(0.34, 0.34), Vec2(0.5, 0.05), Vec2(0, -0.24),
    ]
    static let shot: [Vec2] = [Vec2(0, 0.14), Vec2(0.09, 0), Vec2(0, -0.14), Vec2(-0.09, 0)]
    static let skitterBody: [Vec2] = [Vec2(-0.42, 0), Vec2(0, 0.2), Vec2(0.42, 0), Vec2(0, -0.2)]
    static let broodShell: [Vec2] = [Vec2(-0.42, -0.26), Vec2(0.42, -0.26), Vec2(0.42, 0.26), Vec2(-0.42, 0.26)]
    static let broodCore: [Vec2] = [Vec2(-0.24, 0), Vec2(0, 0.17), Vec2(0.24, 0), Vec2(0, -0.17)]
    static let sowerHull: [Vec2] = regular(8, 0.32)
    static let orbiterCore: [Vec2] = regular(3, 0.34)
    static let orbiterShield: [Vec2] = regular(6, 0.46)
    static let lancerSpindle: [Vec2] = [Vec2(0, 0.44), Vec2(0.17, 0), Vec2(0, -0.44), Vec2(-0.17, 0)]
    static let lancerBar: [Vec2] = [Vec2(-0.38, 0.12), Vec2(0.38, 0.12)]
    static let bolt: [Vec2] = [Vec2(-0.14, -0.1), Vec2(0, 0.22), Vec2(0.14, -0.1)]
    static let mineSpoke: [Vec2] = [Vec2(-0.2, 0), Vec2(0.2, 0)]

    static func skitterLegs(_ phase: Double) -> [Vec2] {
        let k = 0.08 * sin(phase)
        return [Vec2(-0.3, -0.32 + k), Vec2(0, -0.08), Vec2(0.3, -0.32 - k)]
    }

    static func regular(_ sides: Int, _ radius: Double) -> [Vec2] {
        (0..<sides).map { k in
            let a = Double.pi / 2 + 2 * Double.pi * Double(k) / Double(sides)
            return Vec2(radius * cos(a), radius * sin(a))
        }
    }
}

extension Game {
    /// Scale applied around the vanishing point: the well flies in at the
    /// start of a level, and the ship plunges into it during a dive.
    public var cameraZoom: Double {
        switch phase {
        case .levelIntro:
            let t = min(1, phaseTime / Game.introDuration)
            let eased = 1 - pow(1 - t, 3)
            return 0.08 + 0.92 * eased
        case .diving:
            let t = min(1, phaseTime / Game.diveDuration)
            return 1 + 3.5 * t * t
        case .title:
            return 0.92 + 0.04 * sin(time * 1.3)
        default:
            return 1
        }
    }

    public func renderStrokes() -> [Stroke] {
        var out: [Stroke] = []
        out.reserveCapacity(128)
        let zoom = cameraZoom
        let vanishing = tube.vanishingPoint
        let view: (Vec2) -> Vec2 = { vanishing + ($0 - vanishing) * zoom }

        // The well.
        let edgeCount = tube.rim.count
        var near: [Vec2] = []
        var far: [Vec2] = []
        for i in 0..<edgeCount {
            near.append(view(tube.edgePoint(i, depth: 1)))
            far.append(view(tube.edgePoint(i, depth: 0)))
        }
        out.append(Stroke(points: near, closed: tube.isClosed, color: .tube))
        out.append(Stroke(points: far, closed: tube.isClosed, color: .tube))
        for i in 0..<edgeCount {
            out.append(Stroke(points: [far[i], near[i]], closed: false, color: .tube))
        }

        let shipVisible = phase == .levelIntro || phase == .playing || phase == .diving
        if shipVisible {
            let a = player.lane
            let b = tube.isClosed ? (a + 1) % edgeCount : min(a + 1, edgeCount - 1)
            out.append(Stroke(points: [far[a], near[a], near[b], far[b]], closed: false, color: .laneHighlight))
        }

        func glyph(_ shape: [Vec2], at position: Double, depth: Double, color: ColorTag,
                   closed: Bool = true, rotation: Double = 0) {
            let frame = tube.frame(at: position, depth: depth)
            let points = shape.map { view(frame.map(rotation == 0 ? $0 : $0.rotated(by: rotation))) }
            out.append(Stroke(points: points, closed: closed, color: color))
        }

        for mine in mines {
            let position = Double(mine.lane) + 0.5
            for k in 0..<3 {
                glyph(Glyphs.mineSpoke, at: position, depth: mine.depth, color: .mine, closed: false,
                      rotation: time * 2.5 + Double(k) * Double.pi / 3)
            }
        }

        for enemy in enemies {
            let position = renderPosition(of: enemy)
            let depth = enemy.depth
            let wobble = time * 9 + Double(enemy.id)
            switch enemy.kind {
            case .skitter:
                glyph(Glyphs.skitterBody, at: position, depth: depth, color: .skitter)
                glyph(Glyphs.skitterLegs(wobble), at: position, depth: depth, color: .skitter, closed: false)
            case .brood:
                glyph(Glyphs.broodShell, at: position, depth: depth, color: .brood)
                glyph(Glyphs.broodCore, at: position, depth: depth, color: .brood,
                      rotation: 0.3 * sin(wobble * 0.5))
            case .sower:
                glyph(Glyphs.sowerHull, at: position, depth: depth, color: .sower, rotation: time * 1.5)
                glyph(Glyphs.mineSpoke, at: position, depth: depth, color: .sower, closed: false,
                      rotation: Double.pi / 2)
            case .orbiter:
                glyph(Glyphs.orbiterCore, at: position, depth: depth, color: .orbiter, rotation: time * 5)
                if enemy.hitPoints > 1 {
                    glyph(Glyphs.orbiterShield, at: position, depth: depth, color: .orbiterShield,
                          rotation: -time * 2)
                }
            case .lancer:
                glyph(Glyphs.lancerSpindle, at: position, depth: depth, color: .lancer)
                glyph(Glyphs.lancerBar, at: position, depth: depth, color: .lancer, closed: false)
            }
        }

        for bolt in bolts {
            glyph(Glyphs.bolt, at: Double(bolt.lane) + 0.5, depth: bolt.depth, color: .bolt, closed: false)
        }

        for shot in shots {
            glyph(Glyphs.shot, at: Double(shot.lane) + 0.5, depth: shot.depth, color: .shot)
        }

        if shipVisible {
            glyph(Glyphs.player, at: player.displayPosition + 0.5, depth: player.depth, color: .player)
        }

        for burst in bursts {
            let t = burst.age / burst.life
            let outer = burst.size * (0.25 + 0.75 * t)
            let inner = outer * (0.3 + 0.6 * t)
            for k in 0..<burst.rays {
                let angle = burst.spin + 2 * Double.pi * Double(k) / Double(burst.rays)
                let direction = Vec2(cos(angle), sin(angle))
                out.append(Stroke(points: [view(burst.center + direction * inner),
                                           view(burst.center + direction * outer)],
                                  closed: false, color: burst.color))
            }
        }
        return out
    }
}
