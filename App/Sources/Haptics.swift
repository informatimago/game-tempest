// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import UIKit

final class Haptics {
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)

    func heavy() { heavyImpact.impactOccurred() }
    func medium() { mediumImpact.impactOccurred() }
    func light() { lightImpact.impactOccurred() }
}
