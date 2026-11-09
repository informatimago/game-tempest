// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import Foundation

public enum GamePhase: Equatable {
    case title
    case levelIntro
    case playing
    case dying
    case diving
    case gameOver
}

/// Cues for the host (sound, haptics, persistence).
public enum GameEvent: Equatable {
    case fire
    case enemyHit
    case enemyDestroyed(EnemyKind)
    case mineDestroyed
    case boltDestroyed
    case boltFired
    case mineDetonated
    case playerDestroyed
    case overload
    case levelCleared
    case levelStarted(Int)
    case extraLife
    case gameOver
}

public struct GameInput: Equatable {
    /// Where the player is pointing, in view space; nil when not touching.
    public var aim: Vec2?
    public var fire: Bool
    /// Edge-triggered: request the overload blast.
    public var overload: Bool
    /// Edge-triggered: start a game from the title or game-over screen.
    public var start: Bool

    public init(aim: Vec2? = nil, fire: Bool = false, overload: Bool = false, start: Bool = false) {
        self.aim = aim
        self.fire = fire
        self.overload = overload
        self.start = start
    }
}

/// The whole game state and rules, independent of any UI framework.
/// The host calls `step(dt:input:)` at a fixed rate, draws
/// `renderStrokes()`, and plays the cues from `drainEvents()`.
public final class Game {
    // MARK: Tuning

    public static let startingLives = 3
    public static let maximumLives = 9
    public static let extraLifeInterval = 20_000
    public static let maximumShots = 6
    public static let fireInterval = 0.12
    public static let shotSpeed = 2.6
    public static let playerStepInterval = 0.055
    public static let introDuration = 1.4
    public static let diveDuration = 2.2
    public static let deathDuration = 1.8
    public static let gameOverLockout = 1.0
    public static let overloadPerKill = 0.07
    public static let maximumMines = 10
    public static let titleTubeInterval = 4.0
    static let hitMargin = 0.03

    // MARK: State

    public internal(set) var phase: GamePhase = .title
    public internal(set) var phaseTime = 0.0
    public internal(set) var time = 0.0
    public internal(set) var level = 1
    public internal(set) var score = 0
    public internal(set) var lives = Game.startingLives
    public internal(set) var overloadCharge = 0.0
    public internal(set) var overloadFlash = 0.0
    public internal(set) var tube: Tube
    public internal(set) var player = Player()
    public internal(set) var enemies: [Enemy] = []
    public internal(set) var shots: [Shot] = []
    public internal(set) var bolts: [Bolt] = []
    public internal(set) var mines: [Mine] = []
    public internal(set) var bursts: [Burst] = []
    public internal(set) var pendingSpawns: [EnemyKind] = []

    var spawnTimer = 0.0
    var nextExtraLife = Game.extraLifeInterval
    var nextEnemyID = 1
    var diedWhileDiving = false
    var titleTubeIndex = 0
    var rng: SplitMix64
    var events: [GameEvent] = []

    public init(seed: UInt64 = 0x5EED) {
        rng = SplitMix64(seed: seed)
        tube = TubeCatalog.tube(index: 0)
    }

    /// Which tube colour scheme to use: it changes each time the wells cycle.
    public var paletteIndex: Int {
        phase == .title ? 0 : ((level - 1) / TubeCatalog.count) % 4
    }

    /// Enemies get faster with each level.
    var speedScale: Double { 1 + 0.045 * Double(min(level, 40) - 1) }

    public func drainEvents() -> [GameEvent] {
        defer { events.removeAll() }
        return events
    }

    // MARK: Flow

    public func startNewGame(atLevel startLevel: Int = 1) {
        score = 0
        lives = Game.startingLives
        nextExtraLife = Game.extraLifeInterval
        overloadCharge = 0
        overloadFlash = 0
        bursts.removeAll()
        beginLevel(max(1, startLevel))
    }

    func beginLevel(_ newLevel: Int) {
        level = newLevel
        tube = TubeCatalog.tube(forLevel: newLevel)
        enemies.removeAll()
        shots.removeAll()
        bolts.removeAll()
        mines.removeAll()
        pendingSpawns = Game.roster(level: newLevel, rng: &rng)
        spawnTimer = 0.8
        diedWhileDiving = false
        player = Player()
        player.lane = tube.nearestLane(toward: Vec2(0, -1)) ?? 0
        player.displayPosition = Double(player.lane)
        setPhase(.levelIntro)
        events.append(.levelStarted(newLevel))
    }

    func setPhase(_ newPhase: GamePhase) {
        phase = newPhase
        phaseTime = 0
    }

    static func roster(level: Int, rng: inout SplitMix64) -> [EnemyKind] {
        var roster: [EnemyKind] = Array(repeating: .skitter, count: 6 + min(level, 30) / 2)
        if level >= 2 { roster += Array(repeating: .brood, count: min(1 + level / 4, 8)) }
        if level >= 3 { roster += Array(repeating: .lancer, count: min(1 + level / 5, 7)) }
        if level >= 4 { roster += Array(repeating: .sower, count: min(1 + level / 8, 4)) }
        if level >= 6 { roster += Array(repeating: .orbiter, count: min(1 + level / 6, 6)) }
        rng.shuffle(&roster)
        return roster
    }

    // MARK: Stepping

    public func step(dt rawDt: Double, input: GameInput) {
        let dt = min(max(rawDt, 0), 0.05)
        time += dt
        phaseTime += dt
        overloadFlash = max(0, overloadFlash - dt)
        updateBursts(dt)

        switch phase {
        case .title, .gameOver:
            if phase == .title {
                let index = Int(time / Game.titleTubeInterval) % TubeCatalog.count
                if index != titleTubeIndex {
                    titleTubeIndex = index
                    tube = TubeCatalog.tube(index: index)
                }
            }
            if input.start && (phase == .title || phaseTime >= Game.gameOverLockout) {
                startNewGame()
            }
        case .levelIntro:
            updatePlayerMovement(dt, input)
            if phaseTime >= Game.introDuration { setPhase(.playing) }
        case .playing:
            updatePlaying(dt, input)
        case .dying:
            if phaseTime >= Game.deathDuration { afterDeath() }
        case .diving:
            updateDiving(dt, input)
        }
    }

    func updatePlaying(_ dt: Double, _ input: GameInput) {
        updatePlayerMovement(dt, input)
        checkRimCollisions()
        guard phase == .playing else { return }
        updateFiring(dt, input)
        if input.overload { triggerOverload() }
        updateSpawning(dt)
        updateShots(dt)
        updateEnemies(dt)
        guard phase == .playing else { return }
        updateBolts(dt)
        guard phase == .playing else { return }
        updateMines(dt)
        guard phase == .playing else { return }
        if pendingSpawns.isEmpty && enemies.isEmpty { startDive() }
    }

    // MARK: Player

    func updatePlayerMovement(_ dt: Double, _ input: GameInput) {
        player.moveTimer = max(0, player.moveTimer - dt)
        if let aim = input.aim, let target = tube.nearestLane(toward: aim), player.moveTimer <= 0 {
            let steps = tube.laneSteps(from: player.lane, to: target)
            if steps != 0 {
                player.lane = tube.normalizedLane(player.lane + steps.signum()) ?? player.lane
                player.moveTimer = Game.playerStepInterval
            }
        }
        // Ease the drawn position toward the lane, the short way round.
        var delta = Double(player.lane) - player.displayPosition
        if tube.isClosed {
            let n = Double(tube.laneCount)
            if delta > n / 2 { delta -= n } else if delta < -n / 2 { delta += n }
        }
        player.displayPosition += delta * min(1, dt * 28)
        if tube.isClosed {
            let n = Double(tube.laneCount)
            player.displayPosition = player.displayPosition.truncatingRemainder(dividingBy: n)
            if player.displayPosition < 0 { player.displayPosition += n }
        }
    }

    func updateFiring(_ dt: Double, _ input: GameInput) {
        player.fireCooldown = max(0, player.fireCooldown - dt)
        if input.fire && player.fireCooldown <= 0 && shots.count < Game.maximumShots {
            shots.append(Shot(lane: player.lane, depth: player.depth))
            player.fireCooldown = Game.fireInterval
            events.append(.fire)
        }
    }

    func killPlayer() {
        guard phase == .playing || phase == .diving else { return }
        diedWhileDiving = phase == .diving
        addBurst(at: tube.point(at: player.displayPosition + 0.5, depth: player.depth),
                 color: .player, size: 0.3, rays: 18, life: 0.9)
        events.append(.playerDestroyed)
        setPhase(.dying)
    }

    func afterDeath() {
        lives -= 1
        if lives <= 0 {
            setPhase(.gameOver)
            events.append(.gameOver)
            return
        }
        if diedWhileDiving {
            beginLevel(level + 1)
            return
        }
        // Whatever was still alive comes back from the bottom of the well.
        pendingSpawns.insert(contentsOf: enemies.map { $0.kind }, at: 0)
        enemies.removeAll()
        shots.removeAll()
        bolts.removeAll()
        mines.removeAll()
        spawnTimer = 1.0
        player.depth = 1
        setPhase(.levelIntro)
    }

    func award(_ points: Int) {
        score += points
        while score >= nextExtraLife {
            nextExtraLife += Game.extraLifeInterval
            if lives < Game.maximumLives {
                lives += 1
                events.append(.extraLife)
            }
        }
    }

    func triggerOverload() {
        guard overloadCharge >= 1, phase == .playing else { return }
        let doomed = enemies
        enemies.removeAll()
        for enemy in doomed { destroy(enemy, splitting: false) }
        for mine in mines {
            addBurst(at: tube.laneCenter(mine.lane, depth: mine.depth), color: .mine, size: 0.06)
        }
        mines.removeAll()
        bolts.removeAll()
        overloadCharge = 0
        overloadFlash = 0.5
        events.append(.overload)
    }

    // MARK: Dive

    func startDive() {
        award(100 * level)
        shots.removeAll()
        bolts.removeAll()
        events.append(.levelCleared)
        setPhase(.diving)
    }

    func updateDiving(_ dt: Double, _ input: GameInput) {
        updatePlayerMovement(dt, input)
        updateFiring(dt, input)
        updateShots(dt)
        let progress = min(1, phaseTime / Game.diveDuration)
        let previousDepth = player.depth
        player.depth = 1 - progress
        let lane = player.lane
        let low = player.depth - 0.02, high = previousDepth + 0.02
        if let index = mines.firstIndex(where: { $0.lane == lane && $0.depth >= low && $0.depth <= high }) {
            let mine = mines.remove(at: index)
            addBurst(at: tube.laneCenter(mine.lane, depth: mine.depth), color: .mine, size: 0.12)
            events.append(.mineDetonated)
            killPlayer()
            return
        }
        if progress >= 1 { beginLevel(level + 1) }
    }

    // MARK: Enemies

    func updateSpawning(_ dt: Double) {
        guard !pendingSpawns.isEmpty else { return }
        spawnTimer -= dt
        if spawnTimer <= 0 {
            let kind = pendingSpawns.removeFirst()
            spawn(kind)
            spawnTimer = max(0.35, 1.25 - 0.035 * Double(level - 1)) * rng.double(in: 0.7...1.3)
        }
    }

    @discardableResult
    func spawn(_ kind: EnemyKind, lane: Int? = nil, depth: Double = 0) -> Int {
        let lane = lane ?? rng.int(tube.laneCount)
        var enemy = Enemy(id: nextEnemyID, kind: kind, lane: lane, depth: depth)
        nextEnemyID += 1
        switch kind {
        case .skitter:
            enemy.actionTimer = rng.double(in: 0.6...1.6)
        case .brood:
            break
        case .sower:
            enemy.turnDepth = rng.double(in: 0.55...0.85)
            enemy.actionTimer = 0.6
        case .orbiter:
            enemy.orbitDirection = Double(rng.sign())
        case .lancer:
            enemy.turnDepth = rng.double(in: 0.35...0.6)
            enemy.actionTimer = 0.5
        }
        enemies.append(enemy)
        return enemies.count - 1
    }

    /// The lane an enemy currently occupies for hits and collisions.
    public func effectiveLane(of enemy: Enemy) -> Int {
        if enemy.kind == .orbiter {
            return tube.normalizedLane(Int(enemy.orbitPosition.rounded(.down))) ?? enemy.lane
        }
        if enemy.slideDirection != 0 && enemy.slideProgress >= 0.5 {
            return tube.normalizedLane(enemy.lane + enemy.slideDirection) ?? enemy.lane
        }
        return enemy.lane
    }

    /// Continuous position across lanes (edge units) used for drawing.
    public func renderPosition(of enemy: Enemy) -> Double {
        if enemy.kind == .orbiter { return enemy.orbitPosition }
        return Double(enemy.lane) + 0.5 + Double(enemy.slideDirection) * enemy.slideProgress
    }

    func updateEnemies(_ dt: Double) {
        var born: [Enemy] = []
        var i = 0
        while i < enemies.count {
            var enemy = enemies[i]
            var remove = false
            if enemy.kind != .orbiter { advanceSlide(&enemy, dt) }
            switch enemy.kind {
            case .skitter:
                updateSkitter(&enemy, dt)
            case .brood:
                enemy.depth += 0.09 * speedScale * dt
                if enemy.depth >= 1 {
                    enemy.depth = 1
                    born += broodlings(of: enemy, atRim: true)
                    addBurst(at: tube.laneCenter(enemy.lane, depth: 1), color: .brood, size: 0.07)
                    remove = true
                }
            case .sower:
                updateSower(&enemy, dt)
            case .orbiter:
                updateOrbiter(&enemy, dt)
            case .lancer:
                updateLancer(&enemy, dt)
            }
            if remove {
                enemies.remove(at: i)
            } else {
                enemies[i] = enemy
                i += 1
            }
        }
        enemies += born
        checkRimCollisions()
    }

    func advanceSlide(_ enemy: inout Enemy, _ dt: Double) {
        guard enemy.slideDirection != 0 else { return }
        enemy.slideProgress += dt * speedScale / (enemy.mode == .rim ? 0.22 : 0.3)
        if enemy.slideProgress >= 1 {
            enemy.lane = tube.normalizedLane(enemy.lane + enemy.slideDirection) ?? enemy.lane
            enemy.slideDirection = 0
            enemy.slideProgress = 0
        }
    }

    func startSlide(_ enemy: inout Enemy, direction: Int) {
        guard direction != 0 else { return }
        var dir = direction
        if tube.normalizedLane(enemy.lane + dir) == nil { dir = -dir }
        guard tube.normalizedLane(enemy.lane + dir) != nil else { return }
        enemy.slideDirection = dir
        enemy.slideProgress = 0
    }

    /// On the rim, skitters and spent lancers crawl toward the ship.
    func crawlRim(_ enemy: inout Enemy, _ dt: Double) {
        guard enemy.slideDirection == 0 else { return }
        enemy.actionTimer -= dt
        if enemy.actionTimer <= 0 {
            startSlide(&enemy, direction: tube.laneSteps(from: enemy.lane, to: player.lane).signum())
            enemy.actionTimer = 0.35 / speedScale
        }
    }

    func updateSkitter(_ enemy: inout Enemy, _ dt: Double) {
        if enemy.mode == .rim {
            crawlRim(&enemy, dt)
            return
        }
        enemy.depth += 0.16 * speedScale * dt
        if enemy.depth >= 1 {
            enemy.depth = 1
            enemy.mode = .rim
            enemy.actionTimer = 0.25
            return
        }
        guard enemy.slideDirection == 0 else { return }
        enemy.actionTimer -= dt
        if enemy.actionTimer <= 0 {
            let toward = tube.laneSteps(from: enemy.lane, to: player.lane).signum()
            let direction = (toward != 0 && rng.chance(0.65)) ? toward : rng.sign()
            startSlide(&enemy, direction: direction)
            enemy.actionTimer = rng.double(in: 0.7...1.8) / speedScale
        }
    }

    func updateSower(_ enemy: inout Enemy, _ dt: Double) {
        let speed = 0.13 * speedScale * dt
        if enemy.mode == .descending {
            enemy.depth -= speed
            if enemy.depth <= 0 {
                enemy.depth = 0
                enemy.mode = .climbing
                enemy.lane = rng.int(tube.laneCount)
                enemy.turnDepth = rng.double(in: 0.55...0.85)
            }
        } else {
            enemy.depth += speed
            if enemy.depth >= enemy.turnDepth { enemy.mode = .descending }
        }
        enemy.actionTimer -= dt
        if enemy.actionTimer <= 0 {
            enemy.actionTimer = 1.0 / speedScale
            layMine(lane: enemy.lane, depth: enemy.depth)
        }
    }

    func layMine(lane: Int, depth: Double) {
        guard depth > 0.12 && depth < 0.9, mines.count < Game.maximumMines else { return }
        guard !mines.contains(where: { $0.lane == lane && abs($0.depth - depth) < 0.1 }) else { return }
        mines.append(Mine(lane: lane, depth: depth))
    }

    func updateOrbiter(_ enemy: inout Enemy, _ dt: Double) {
        enemy.depth = min(1, enemy.depth + 0.07 * speedScale * dt)
        if enemy.depth >= 1 { enemy.mode = .rim }
        let speed = (enemy.mode == .rim ? 2.2 : 1.5) * speedScale
        enemy.orbitPosition += enemy.orbitDirection * speed * dt
        let n = Double(tube.laneCount)
        if tube.isClosed {
            enemy.orbitPosition = enemy.orbitPosition.truncatingRemainder(dividingBy: n)
            if enemy.orbitPosition < 0 { enemy.orbitPosition += n }
        } else if enemy.orbitPosition < 0.5 {
            enemy.orbitPosition = 0.5
            enemy.orbitDirection = 1
        } else if enemy.orbitPosition > n - 0.5 {
            enemy.orbitPosition = n - 0.5
            enemy.orbitDirection = -1
        }
        enemy.lane = effectiveLane(of: enemy)
    }

    func updateLancer(_ enemy: inout Enemy, _ dt: Double) {
        switch enemy.mode {
        case .climbing, .descending:
            enemy.depth += 0.17 * speedScale * dt
            if enemy.volleys < 3 && enemy.depth >= enemy.turnDepth {
                enemy.mode = .holding
                enemy.actionTimer = 0.5
            } else if enemy.depth >= 1 {
                enemy.depth = 1
                enemy.mode = .rim
                enemy.actionTimer = 0.3
            }
        case .holding:
            enemy.actionTimer -= dt
            if enemy.actionTimer <= 0 {
                bolts.append(Bolt(lane: enemy.lane, depth: enemy.depth + 0.02))
                events.append(.boltFired)
                enemy.volleys += 1
                enemy.actionTimer = 1.3 / speedScale
                if enemy.volleys >= 3 { enemy.mode = .climbing }
            }
        case .rim:
            crawlRim(&enemy, dt)
        }
    }

    func broodlings(of brood: Enemy, atRim: Bool) -> [Enemy] {
        var result: [Enemy] = []
        for direction in [-1, 1] {
            guard let lane = tube.normalizedLane(brood.lane + direction) else { continue }
            var child = Enemy(id: nextEnemyID, kind: .skitter, lane: lane, depth: brood.depth)
            nextEnemyID += 1
            child.mode = atRim ? .rim : .climbing
            child.actionTimer = atRim ? 0.4 : rng.double(in: 0.4...1.2)
            result.append(child)
        }
        return result
    }

    func checkRimCollisions() {
        guard phase == .playing else { return }
        for enemy in enemies where enemy.mode == .rim {
            let touching: Bool
            if enemy.kind == .orbiter {
                touching = tube.positionDistance(enemy.orbitPosition, Double(player.lane) + 0.5) < 0.3
            } else {
                touching = enemy.slideDirection == 0 && enemy.lane == player.lane
            }
            if touching {
                killPlayer()
                return
            }
        }
    }

    // MARK: Projectiles

    func updateShots(_ dt: Double) {
        var survivors: [Shot] = []
        for var shot in shots {
            let from = shot.depth
            shot.depth -= Game.shotSpeed * dt
            if resolveShot(lane: shot.lane, from: from, to: shot.depth) { continue }
            if shot.depth > 0 { survivors.append(shot) }
        }
        shots = survivors
    }

    /// Hits the nearest target in `lane` between depths `to` and `from`.
    /// Returns true if the shot was spent.
    func resolveShot(lane: Int, from: Double, to: Double) -> Bool {
        enum Target {
            case enemy(Int)
            case bolt(Int)
            case mine(Int)
        }
        let low = to - Game.hitMargin, high = from + Game.hitMargin
        var best: Target?
        var bestDepth = -Double.infinity
        for (i, enemy) in enemies.enumerated()
            where effectiveLane(of: enemy) == lane && enemy.depth >= low && enemy.depth <= high && enemy.depth > bestDepth {
            best = .enemy(i)
            bestDepth = enemy.depth
        }
        for (i, bolt) in bolts.enumerated()
            where bolt.lane == lane && bolt.depth >= low && bolt.depth <= high && bolt.depth > bestDepth {
            best = .bolt(i)
            bestDepth = bolt.depth
        }
        for (i, mine) in mines.enumerated()
            where mine.lane == lane && mine.depth >= low && mine.depth <= high && mine.depth > bestDepth {
            best = .mine(i)
            bestDepth = mine.depth
        }
        guard let target = best else { return false }
        switch target {
        case .enemy(let i):
            damageEnemy(at: i)
        case .bolt(let i):
            let bolt = bolts.remove(at: i)
            addBurst(at: tube.laneCenter(bolt.lane, depth: bolt.depth), color: .bolt, size: 0.04, rays: 6)
            award(25)
            events.append(.boltDestroyed)
        case .mine(let i):
            let mine = mines.remove(at: i)
            addBurst(at: tube.laneCenter(mine.lane, depth: mine.depth), color: .mine, size: 0.06)
            award(50)
            events.append(.mineDestroyed)
        }
        return true
    }

    func damageEnemy(at index: Int) {
        enemies[index].hitPoints -= 1
        if enemies[index].hitPoints > 0 {
            award(50)
            events.append(.enemyHit)
            return
        }
        let enemy = enemies.remove(at: index)
        destroy(enemy, splitting: true)
    }

    func destroy(_ enemy: Enemy, splitting: Bool) {
        award(enemy.kind.points)
        addBurst(at: tube.point(at: renderPosition(of: enemy), depth: enemy.depth),
                 color: ColorTag.forEnemy(enemy.kind), size: 0.1)
        events.append(.enemyDestroyed(enemy.kind))
        overloadCharge = min(1, overloadCharge + Game.overloadPerKill)
        if splitting && enemy.kind == .brood {
            enemies += broodlings(of: enemy, atRim: enemy.mode == .rim)
        }
    }

    func updateBolts(_ dt: Double) {
        var kept: [Bolt] = []
        var hitPlayer = false
        for var bolt in bolts {
            bolt.depth += 0.5 * speedScale * dt
            if bolt.depth >= 1 {
                addBurst(at: tube.laneCenter(bolt.lane, depth: 1), color: .bolt, size: 0.05, rays: 6)
                if bolt.lane == player.lane { hitPlayer = true }
                continue
            }
            kept.append(bolt)
        }
        bolts = kept
        if hitPlayer { killPlayer() }
    }

    func updateMines(_ dt: Double) {
        var kept: [Mine] = []
        var hitPlayer = false
        for var mine in mines {
            mine.depth += 0.022 * speedScale * dt
            if mine.depth >= 1 {
                addBurst(at: tube.laneCenter(mine.lane, depth: 1), color: .mine, size: 0.12)
                events.append(.mineDetonated)
                if mine.lane == player.lane { hitPlayer = true }
                continue
            }
            kept.append(mine)
        }
        mines = kept
        if hitPlayer { killPlayer() }
    }

    // MARK: Effects

    func addBurst(at center: Vec2, color: ColorTag, size: Double, rays: Int = 10, life: Double = 0.55) {
        bursts.append(Burst(center: center, life: life, size: size, rays: rays,
                            spin: rng.double(in: 0...(2 * Double.pi)), color: color))
    }

    func updateBursts(_ dt: Double) {
        guard !bursts.isEmpty else { return }
        for i in bursts.indices { bursts[i].age += dt }
        bursts.removeAll { $0.age >= $0.life }
    }
}
