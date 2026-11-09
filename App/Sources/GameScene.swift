// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import RimwardCore
import SpriteKit
import UIKit

/// Draws the game's render list as glowing vector lines, feeds it touch
/// input at a fixed 120 Hz step, and turns its events into sound and haptics.
///
/// Controls: one finger anywhere steers the ship toward that direction
/// (seen from the centre of the well) and fires while it is down;
/// a second finger fires the overload blast when the meter is full.
final class GameScene: SKScene {
    private static let highScoreKey = "rimward.highScore"
    private static let fontName = "Menlo-Bold"

    private let game = Game(seed: UInt64.random(in: 1...UInt64.max))
    private let sound = SoundEngine()
    private let haptics = Haptics()

    private var glowNodes: [ColorTag: SKShapeNode] = [:]
    private var lineNodes: [ColorTag: SKShapeNode] = [:]

    private let scoreLabel = GameScene.makeLabel(size: 20)
    private let highScoreLabel = GameScene.makeLabel(size: 13)
    private let levelLabel = GameScene.makeLabel(size: 13)
    private let livesLabel = GameScene.makeLabel(size: 13)
    private let pauseLabel = GameScene.makeLabel(size: 22)
    private let messageLabel = GameScene.makeLabel(size: 34)
    private let subtitleLabel = GameScene.makeLabel(size: 15)
    private let helpLabel = GameScene.makeLabel(size: 11)
    private let overloadLabel = GameScene.makeLabel(size: 11)
    private let overloadFrame = SKShapeNode()
    private let overloadFill = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1))

    private var built = false
    private var lastUpdateTime: TimeInterval?
    private var accumulator = 0.0
    private let fixedStep = 1.0 / 120.0
    private var aimTouch: UITouch?
    private var aimLocation: CGPoint?
    private var pendingStart = false
    private var pendingOverload = false
    private var gamePaused = false
    private var highScore = UserDefaults.standard.integer(forKey: GameScene.highScoreKey)

    /// Screen points per unit of the game's view space.
    private var unit: CGFloat { min(size.width, size.height) * 0.46 }

    private static func makeLabel(size: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: fontName)
        label.fontSize = size
        label.fontColor = Palette.text
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 10
        return label
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Setup

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        if !built { build() }
        layoutHUD()
    }

    private func build() {
        built = true
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.background

        for tag in ColorTag.allCases {
            let color = Palette.color(for: tag)
            let glow = SKShapeNode()
            glow.lineWidth = tag == .tube ? 6 : 8
            glow.strokeColor = color.withAlphaComponent(0.22)
            let line = SKShapeNode()
            line.lineWidth = tag == .tube ? 1.4 : 2
            line.strokeColor = color
            for (node, z) in [(glow, CGFloat(1)), (line, CGFloat(2))] {
                node.lineCap = .round
                node.lineJoin = .round
                node.blendMode = .add
                node.isAntialiased = true
                node.zPosition = z
                addChild(node)
            }
            glowNodes[tag] = glow
            lineNodes[tag] = line
        }

        pauseLabel.text = "II"
        pauseLabel.horizontalAlignmentMode = .right
        scoreLabel.horizontalAlignmentMode = .left
        levelLabel.horizontalAlignmentMode = .left
        livesLabel.horizontalAlignmentMode = .right
        highScoreLabel.fontColor = Palette.dimText
        subtitleLabel.fontColor = Palette.dimText
        helpLabel.fontColor = Palette.dimText
        overloadLabel.fontColor = Palette.dimText
        for label in [scoreLabel, highScoreLabel, levelLabel, livesLabel, pauseLabel,
                      messageLabel, subtitleLabel, helpLabel, overloadLabel] {
            addChild(label)
        }

        overloadFrame.strokeColor = Palette.overloadCharging
        overloadFrame.lineWidth = 1
        overloadFrame.zPosition = 10
        addChild(overloadFrame)
        overloadFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        overloadFill.zPosition = 9
        addChild(overloadFill)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHUD()
    }

    func layoutHUD() {
        guard built else { return }
        let insets = view?.safeAreaInsets ?? .zero
        let halfWidth = size.width / 2, halfHeight = size.height / 2
        let top = halfHeight - insets.top - 22
        let left = -halfWidth + insets.left + 16
        let right = halfWidth - insets.right - 16
        let bottom = -halfHeight + insets.bottom

        scoreLabel.position = CGPoint(x: left, y: top)
        levelLabel.position = CGPoint(x: left, y: top - 24)
        highScoreLabel.position = CGPoint(x: 0, y: top)
        pauseLabel.position = CGPoint(x: right, y: top)
        livesLabel.position = CGPoint(x: right, y: top - 24)
        messageLabel.position = CGPoint(x: 0, y: 24)
        subtitleLabel.position = CGPoint(x: 0, y: -14)
        helpLabel.position = CGPoint(x: 0, y: bottom + 64)

        let barWidth = min(size.width * 0.6, 320)
        let barY = bottom + 26
        overloadFrame.path = CGPath(rect: CGRect(x: -barWidth / 2, y: barY - 4, width: barWidth, height: 8),
                                    transform: nil)
        overloadFill.position = CGPoint(x: -barWidth / 2, y: barY)
        overloadFill.size = CGSize(width: barWidth, height: 8)
        overloadLabel.position = CGPoint(x: 0, y: barY + 16)
    }

    @objc private func applicationWillResignActive() {
        if game.phase != .title && game.phase != .gameOver { gamePaused = true }
        aimTouch = nil
        aimLocation = nil
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if pauseLabel.frame.insetBy(dx: -28, dy: -18).contains(location) {
                togglePause()
                continue
            }
            if gamePaused {
                togglePause()
                continue
            }
            if aimTouch == nil {
                aimTouch = touch
                aimLocation = location
                pendingStart = true
            } else {
                pendingOverload = true
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let aimTouch, touches.contains(aimTouch) {
            aimLocation = aimTouch.location(in: self)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseTouches(touches)
    }

    private func releaseTouches(_ touches: Set<UITouch>) {
        if let aimTouch, touches.contains(aimTouch) {
            self.aimTouch = nil
            aimLocation = nil
        }
    }

    private func togglePause() {
        guard game.phase != .title && game.phase != .gameOver else { return }
        gamePaused.toggle()
        lastUpdateTime = nil
        aimTouch = nil
        aimLocation = nil
    }

    private func worldPoint(_ point: CGPoint) -> Vec2 {
        let u = Double(unit)
        return Vec2(Double(point.x) / u, Double(point.y) / u)
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        let elapsed = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime

        if !gamePaused {
            accumulator = min(accumulator + elapsed, 0.25)
            var input = GameInput(aim: aimLocation.map { self.worldPoint($0) },
                                  fire: aimTouch != nil,
                                  overload: pendingOverload,
                                  start: pendingStart)
            while accumulator >= fixedStep {
                game.step(dt: fixedStep, input: input)
                accumulator -= fixedStep
                // Edge-triggered requests are delivered to one step only.
                input.overload = false
                input.start = false
                pendingOverload = false
                pendingStart = false
            }
        }

        handleEvents()
        renderWorld()
        updateHUD()
    }

    private func handleEvents() {
        for event in game.drainEvents() {
            switch event {
            case .fire:
                sound.play(.fire)
            case .enemyHit:
                sound.play(.hit)
            case .enemyDestroyed, .mineDestroyed, .boltDestroyed:
                sound.play(.explode)
            case .boltFired:
                sound.play(.zap)
            case .mineDetonated:
                sound.play(.thump)
                haptics.light()
            case .playerDestroyed:
                sound.play(.death)
                haptics.heavy()
            case .overload:
                sound.play(.overload)
                haptics.medium()
            case .levelCleared:
                sound.play(.dive)
            case .levelStarted:
                break
            case .extraLife:
                sound.play(.bonus)
            case .gameOver:
                saveHighScore()
            }
        }
    }

    private func renderWorld() {
        let u = Double(unit)
        var paths: [ColorTag: CGMutablePath] = [:]
        for stroke in game.renderStrokes() {
            guard let first = stroke.points.first else { continue }
            let path: CGMutablePath
            if let existing = paths[stroke.color] {
                path = existing
            } else {
                path = CGMutablePath()
                paths[stroke.color] = path
            }
            path.move(to: CGPoint(x: first.x * u, y: first.y * u))
            for point in stroke.points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * u, y: point.y * u))
            }
            if stroke.closed { path.closeSubpath() }
        }

        let tubeColor = game.overloadFlash > 0 ? Palette.overloadFlash : Palette.tubeColor(game.paletteIndex)
        lineNodes[.tube]?.strokeColor = tubeColor
        glowNodes[.tube]?.strokeColor = tubeColor.withAlphaComponent(0.22)

        for tag in ColorTag.allCases {
            let path = paths[tag]
            glowNodes[tag]?.path = path
            lineNodes[tag]?.path = path
        }
    }

    // MARK: HUD

    private func updateHUD() {
        if game.score > highScore { highScore = game.score }
        let inGame = game.phase != .title
        scoreLabel.text = inGame ? String(format: "%07ld", game.score) : ""
        highScoreLabel.text = String(format: "HI %07ld", highScore)
        levelLabel.text = inGame ? "LEVEL \(game.level)  \(game.tube.name.uppercased())" : ""
        livesLabel.text = inGame ? "SHIPS \(max(0, game.lives))" : ""
        pauseLabel.isHidden = !inGame || game.phase == .gameOver

        let showMeter = game.phase == .playing || game.phase == .levelIntro || game.phase == .diving
        overloadFrame.isHidden = !showMeter
        overloadFill.isHidden = !showMeter
        overloadLabel.isHidden = !showMeter
        overloadFill.xScale = CGFloat(max(0.001, game.overloadCharge))
        if game.overloadCharge >= 1 {
            let pulse = 0.6 + 0.4 * sin(game.time * 8)
            overloadFill.color = Palette.overloadReady.withAlphaComponent(CGFloat(pulse))
            overloadLabel.text = "OVERLOAD READY: TAP A SECOND FINGER"
            overloadLabel.fontColor = Palette.overloadReady
        } else {
            overloadFill.color = Palette.overloadCharging
            overloadLabel.text = "OVERLOAD"
            overloadLabel.fontColor = Palette.dimText
        }

        var message = ""
        var subtitle = ""
        var help = ""
        if gamePaused {
            message = "PAUSED"
            subtitle = "TOUCH TO RESUME"
        } else {
            switch game.phase {
            case .title:
                message = "RIMWARD"
                subtitle = "TOUCH TO START"
                help = "POINT TO STEER - HOLD TO FIRE - SECOND FINGER: OVERLOAD"
            case .levelIntro:
                message = "LEVEL \(game.level)"
                subtitle = game.tube.name.uppercased()
            case .diving:
                message = game.phaseTime < 1.0 ? "WELL CLEARED" : ""
                subtitle = game.phaseTime < 1.0 ? "MIND THE MINES" : ""
            case .gameOver:
                message = "GAME OVER"
                subtitle = game.phaseTime >= Game.gameOverLockout ? "TOUCH TO PLAY AGAIN" : ""
            case .playing, .dying:
                break
            }
        }
        messageLabel.text = message
        subtitleLabel.text = subtitle
        helpLabel.text = help
    }

    private func saveHighScore() {
        let stored = UserDefaults.standard.integer(forKey: GameScene.highScoreKey)
        if highScore > stored {
            UserDefaults.standard.set(highScore, forKey: GameScene.highScoreKey)
        }
    }
}
