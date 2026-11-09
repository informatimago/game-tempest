// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import XCTest
@testable import RimwardCore

final class GameTests: XCTestCase {
    let tick = 1.0 / 120.0

    /// A game on level 1, past the intro, with no enemies queued.
    func playingGame(seed: UInt64 = 42) -> Game {
        let game = Game(seed: seed)
        game.startNewGame()
        game.pendingSpawns.removeAll()
        while game.phase == .levelIntro { game.step(dt: tick, input: GameInput()) }
        XCTAssertEqual(game.phase, .playing)
        return game
    }

    func run(_ game: Game, seconds: Double, input: GameInput = GameInput(), until done: (Game) -> Bool = { _ in false }) {
        var t = 0.0
        while t < seconds && !done(game) {
            game.step(dt: tick, input: input)
            t += tick
        }
    }

    func testTitleStartsAGame() {
        let game = Game(seed: 1)
        XCTAssertEqual(game.phase, .title)
        game.step(dt: tick, input: GameInput(start: true))
        XCTAssertEqual(game.phase, .levelIntro)
        XCTAssertEqual(game.level, 1)
        XCTAssertEqual(game.lives, Game.startingLives)
        XCTAssertTrue(game.drainEvents().contains(.levelStarted(1)))
    }

    func testShotDestroysASkitter() {
        let game = playingGame()
        let index = game.spawn(.skitter, lane: game.player.lane, depth: 0.4)
        game.enemies[index].actionTimer = 100
        run(game, seconds: 1, input: GameInput(fire: true)) { $0.enemies.isEmpty }
        XCTAssertTrue(game.enemies.isEmpty)
        XCTAssertGreaterThanOrEqual(game.score, EnemyKind.skitter.points)
        XCTAssertGreaterThan(game.overloadCharge, 0)
    }

    func testBroodSplitsIntoTwoSkitters() {
        let game = playingGame()
        let lane = game.player.lane
        let index = game.spawn(.brood, lane: lane, depth: 0.5)
        game.damageEnemy(at: index)
        XCTAssertEqual(game.enemies.count, 2)
        XCTAssertTrue(game.enemies.allSatisfy { $0.kind == .skitter })
        let lanes = Set(game.enemies.map { $0.lane })
        XCTAssertEqual(lanes, [game.tube.normalizedLane(lane - 1)!, game.tube.normalizedLane(lane + 1)!])
    }

    func testOrbiterNeedsTwoHits() {
        let game = playingGame()
        let index = game.spawn(.orbiter, lane: 3, depth: 0.5)
        game.damageEnemy(at: index)
        XCTAssertEqual(game.enemies.count, 1)
        game.damageEnemy(at: 0)
        XCTAssertTrue(game.enemies.isEmpty)
    }

    func testRimSkitterInTheShipsLaneIsFatal() {
        let game = playingGame()
        let index = game.spawn(.skitter, lane: game.player.lane, depth: 1)
        game.enemies[index].mode = .rim
        game.enemies[index].actionTimer = 100
        game.step(dt: tick, input: GameInput())
        XCTAssertEqual(game.phase, .dying)
        XCTAssertTrue(game.drainEvents().contains(.playerDestroyed))
    }

    func testClearingTheWellDivesToTheNextLevel() {
        let game = playingGame()
        game.step(dt: tick, input: GameInput())
        XCTAssertEqual(game.phase, .diving)
        run(game, seconds: Game.diveDuration + 0.2) { $0.phase != .diving }
        XCTAssertEqual(game.phase, .levelIntro)
        XCTAssertEqual(game.level, 2)
        XCTAssertEqual(game.tube, TubeCatalog.tube(forLevel: 2))
    }

    func testAMineInTheShipsLaneWrecksTheDive() {
        let game = playingGame()
        game.mines.append(Mine(lane: game.player.lane, depth: 0.5))
        run(game, seconds: Game.diveDuration + 0.2) { $0.phase == .dying || $0.level == 2 }
        XCTAssertEqual(game.phase, .dying)
        XCTAssertEqual(game.level, 1)
    }

    func testShootingTheMineClearsTheDive() {
        let game = playingGame()
        game.mines.append(Mine(lane: game.player.lane, depth: 0.5))
        game.step(dt: tick, input: GameInput())
        XCTAssertEqual(game.phase, .diving)
        run(game, seconds: Game.diveDuration + 0.2, input: GameInput(fire: true)) { $0.phase != .diving }
        XCTAssertEqual(game.level, 2)
    }

    func testOverloadClearsTheWell() {
        let game = playingGame()
        game.spawn(.skitter, lane: 0, depth: 0.3)
        game.spawn(.lancer, lane: 5, depth: 0.2)
        game.mines.append(Mine(lane: 7, depth: 0.4))
        game.overloadCharge = 1
        game.step(dt: tick, input: GameInput(overload: true))
        XCTAssertTrue(game.enemies.isEmpty)
        XCTAssertTrue(game.mines.isEmpty)
        XCTAssertEqual(game.overloadCharge, 0)
        XCTAssertTrue(game.drainEvents().contains(.overload))
    }

    func testOverloadNeedsAFullCharge() {
        let game = playingGame()
        game.spawn(.skitter, lane: 0, depth: 0.3)
        game.overloadCharge = 0.5
        game.step(dt: tick, input: GameInput(overload: true))
        XCTAssertEqual(game.enemies.count, 1)
    }

    func testLosingTheLastShipEndsTheGame() {
        let game = playingGame()
        game.lives = 1
        let index = game.spawn(.skitter, lane: game.player.lane, depth: 1)
        game.enemies[index].mode = .rim
        game.step(dt: tick, input: GameInput())
        run(game, seconds: Game.deathDuration + 0.2) { $0.phase != .dying }
        XCTAssertEqual(game.phase, .gameOver)
        // A touch right after the end does not restart at once.
        game.step(dt: tick, input: GameInput(start: true))
        XCTAssertEqual(game.phase, .gameOver)
    }

    func testDeathRequeuesTheSurvivors() {
        let game = playingGame()
        let index = game.spawn(.skitter, lane: game.player.lane, depth: 1)
        game.enemies[index].mode = .rim
        game.spawn(.lancer, lane: 3, depth: 0.1)
        game.step(dt: tick, input: GameInput())
        run(game, seconds: Game.deathDuration + 0.2) { $0.phase != .dying }
        XCTAssertEqual(game.phase, .levelIntro)
        XCTAssertEqual(game.lives, Game.startingLives - 1)
        XCTAssertTrue(game.enemies.isEmpty)
        XCTAssertEqual(game.pendingSpawns.count, 2)
    }

    func testExtraShipEveryInterval() {
        let game = playingGame()
        game.award(Game.extraLifeInterval)
        XCTAssertEqual(game.lives, Game.startingLives + 1)
        XCTAssertTrue(game.drainEvents().contains(.extraLife))
    }

    func testAimingMovesTheShipOneLaneAtATime() {
        let game = playingGame()
        let start = game.player.lane
        let target = game.tube.normalizedLane(start + 4)!
        let aim = game.tube.laneCenter(target, depth: 1)
        game.spawn(.sower, lane: 0, depth: 0.0)  // keep the level from ending
        game.step(dt: tick, input: GameInput(aim: aim))
        XCTAssertEqual(abs(game.tube.laneSteps(from: start, to: game.player.lane)), 1)
        run(game, seconds: 1, input: GameInput(aim: aim)) { $0.player.lane == target }
        XCTAssertEqual(game.player.lane, target)
    }

    func testLancerFiresBoltsUpItsLane() {
        let game = playingGame()
        let index = game.spawn(.lancer, lane: 2, depth: 0.5)
        game.enemies[index].turnDepth = 0.5
        run(game, seconds: 2) { !$0.bolts.isEmpty }
        XCTAssertFalse(game.bolts.isEmpty)
        XCTAssertEqual(game.bolts.first?.lane, 2)
    }

    func testRosterGrowsWithLevel() {
        var rng = SplitMix64(seed: 7)
        let first = Game.roster(level: 1, rng: &rng)
        let later = Game.roster(level: 12, rng: &rng)
        XCTAssertTrue(first.allSatisfy { $0 == .skitter })
        XCTAssertGreaterThan(later.count, first.count)
        XCTAssertEqual(Set(later), Set(EnemyKind.allCases))
    }

    func testSameSeedSameGame() {
        let a = Game(seed: 99), b = Game(seed: 99)
        for g in [a, b] {
            g.startNewGame()
            run(g, seconds: 6, input: GameInput(fire: true))
        }
        XCTAssertEqual(a.enemies, b.enemies)
        XCTAssertEqual(a.score, b.score)
    }

    func testRenderListDrawsTheWellAndTheShip() {
        let game = playingGame()
        game.spawn(.orbiter, lane: 1, depth: 0.5)
        let strokes = game.renderStrokes()
        XCTAssertTrue(strokes.contains { $0.color == .tube })
        XCTAssertTrue(strokes.contains { $0.color == .player })
        XCTAssertTrue(strokes.contains { $0.color == .orbiterShield })
        for stroke in strokes { XCTAssertGreaterThanOrEqual(stroke.points.count, 2) }
    }
}
