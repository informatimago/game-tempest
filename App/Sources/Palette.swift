// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import RimwardCore
import UIKit

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

enum Palette {
    static let background = UIColor(rgb: 0x05030F)
    static let text = UIColor(rgb: 0xF2EEFF)
    static let dimText = UIColor(rgb: 0x8F86B8)
    static let overloadFlash = UIColor(rgb: 0xFFFFFF)
    static let overloadReady = UIColor(rgb: 0xFF5BD1)
    static let overloadCharging = UIColor(rgb: 0x6C5BD8)

    /// The well changes colour each time the twelve wells have been cleared.
    static let tubeCycle: [UIColor] = [
        UIColor(rgb: 0x7B5CFF), // violet
        UIColor(rgb: 0x18C9B5), // teal
        UIColor(rgb: 0xFF7A3D), // ember
        UIColor(rgb: 0x5AA8FF), // ice
    ]

    static func tubeColor(_ index: Int) -> UIColor {
        tubeCycle[((index % tubeCycle.count) + tubeCycle.count) % tubeCycle.count]
    }

    static func color(for tag: ColorTag) -> UIColor {
        switch tag {
        case .tube: return tubeCycle[0]
        case .laneHighlight: return UIColor(rgb: 0xD7CCFF)
        case .player: return UIColor(rgb: 0xFFD23F)
        case .shot: return UIColor(rgb: 0xFFF6D6)
        case .skitter: return UIColor(rgb: 0x7CFF6B)
        case .brood: return UIColor(rgb: 0xFF8C42)
        case .sower: return UIColor(rgb: 0xFF4FD8)
        case .orbiter: return UIColor(rgb: 0x4FD6FF)
        case .orbiterShield: return UIColor(rgb: 0x2A7FFF)
        case .lancer: return UIColor(rgb: 0xFF5A6E)
        case .bolt: return UIColor(rgb: 0xFFB3BD)
        case .mine: return UIColor(rgb: 0xFF3B3B)
        }
    }
}
