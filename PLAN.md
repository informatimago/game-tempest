# Plan

## Done (0.1.0)

- Game core: 12 procedural wells, 5 enemy kinds, mines, bolts, overload,
  dive between levels, extra ships, deterministic seeded RNG.
- iOS app: SpriteKit vector renderer with additive glow, touch steering by
  direction, overload with a second finger, pause, high score, synthesized
  sound, haptics, app icon.
- Unit tests for the core; macOS CI (unit tests + simulator build).

## Next

- Verify on a device: tune speeds, the touch steering feel, and line widths.
- Choice of starting level (unlocked by the best level reached).
- Game controller and hardware keyboard support (GameController framework).
- A background music loop (synthesized, like the effects).
- Particle trails and a short screen shake on death.
- Game Center leaderboard.
- macOS / tvOS front ends over the same core.
