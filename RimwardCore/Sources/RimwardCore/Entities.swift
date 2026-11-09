// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

/// The things that climb out of the well.
public enum EnemyKind: String, CaseIterable, Equatable {
    /// Climbs its lane, side-stepping now and then; on the rim it crawls
    /// toward the ship.
    case skitter
    /// A slow carrier; when shot (or when it reaches the rim) it bursts
    /// into two skitters in the neighbouring lanes.
    case brood
    /// Climbs half way, sinks back, climbs again elsewhere, sowing mines
    /// that drift slowly up toward the rim.
    case sower
    /// Shielded (two hits); sweeps round the well while it climbs.
    case orbiter
    /// Stops mid-well and fires bolts up its lane, then climbs on.
    case lancer

    public var points: Int {
        switch self {
        case .skitter: return 150
        case .brood: return 250
        case .sower: return 300
        case .orbiter: return 500
        case .lancer: return 350
        }
    }

    public var hitPoints: Int { self == .orbiter ? 2 : 1 }
}

public enum EnemyMode: Equatable {
    case climbing
    case holding
    case descending
    case rim
}

public struct Enemy: Equatable {
    public let id: Int
    public let kind: EnemyKind
    public var lane: Int
    public var depth: Double
    public var hitPoints: Int
    public var mode: EnemyMode = .climbing
    /// -1, 0 or +1: the lane it is moving to, while it moves.
    public var slideDirection = 0
    /// 0 ..< 1 while sliding.
    public var slideProgress = 0.0
    /// Orbiters move continuously across lanes (edge units, lane center at +0.5).
    public var orbitPosition = 0.0
    public var orbitDirection = 1.0
    public var actionTimer = 0.0
    public var turnDepth = 1.0
    public var volleys = 0

    public init(id: Int, kind: EnemyKind, lane: Int, depth: Double) {
        self.id = id
        self.kind = kind
        self.lane = lane
        self.depth = depth
        self.hitPoints = kind.hitPoints
        self.orbitPosition = Double(lane) + 0.5
    }
}

public struct Player: Equatable {
    public var lane = 0
    /// Eased lane position used for drawing.
    public var displayPosition = 0.0
    /// 1 on the rim; decreases while diving to the next well.
    public var depth = 1.0
    public var moveTimer = 0.0
    public var fireCooldown = 0.0

    public init() {}
}

public struct Shot: Equatable {
    public var lane: Int
    public var depth: Double

    public init(lane: Int, depth: Double) {
        self.lane = lane
        self.depth = depth
    }
}

/// A lancer's projectile, travelling up its lane.
public struct Bolt: Equatable {
    public var lane: Int
    public var depth: Double

    public init(lane: Int, depth: Double) {
        self.lane = lane
        self.depth = depth
    }
}

/// A sower's mine, drifting up; it detonates on reaching the rim, and it
/// blocks the ship's dive to the next well.
public struct Mine: Equatable {
    public var lane: Int
    public var depth: Double

    public init(lane: Int, depth: Double) {
        self.lane = lane
        self.depth = depth
    }
}

/// An explosion: a ring of rays expanding in view space.
public struct Burst: Equatable {
    public var center: Vec2
    public var age: Double
    public var life: Double
    public var size: Double
    public var rays: Int
    public var spin: Double
    public var color: ColorTag

    public init(center: Vec2, age: Double = 0, life: Double, size: Double, rays: Int, spin: Double, color: ColorTag) {
        self.center = center
        self.age = age
        self.life = life
        self.size = size
        self.rays = rays
        self.spin = spin
        self.color = color
    }
}
