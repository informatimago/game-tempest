// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private var scene: GameScene?

    override func loadView() {
        let skView = SKView()
        skView.isMultipleTouchEnabled = true
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 120
        skView.backgroundColor = Palette.background
        view = skView
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let skView = view as? SKView, skView.bounds.width > 0, skView.bounds.height > 0 else { return }
        if let scene {
            scene.layoutHUD()
        } else {
            let newScene = GameScene(size: skView.bounds.size)
            newScene.scaleMode = .resizeFill
            skView.presentScene(newScene)
            scene = newScene
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        scene?.layoutHUD()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
}
