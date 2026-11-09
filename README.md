# Rimward

An original vector **tube shooter** for iPhone and iPad, written in Swift
with SpriteKit.

You hold the rim of a glowing well. Things climb out of its depths along
the lanes; you slide round the rim and shoot down the lanes before they
reach you. Clear the well, then dive into it to reach the next one, and
don't hit the mines on the way down.

Rimward belongs to the genre of the early-1980s arcade tube shooters, but
its name, enemies, wells, rules, artwork and sounds are its own.

## Playing

| Gesture | Effect |
|---|---|
| One finger anywhere | Steers the ship toward the lane in that direction, as seen from the centre of the well, and fires while held. |
| Second finger (when the meter is full) | **Overload**: destroys everything in the well. |
| `II` (top right) | Pause. The game also pauses when the app is sent to the background. |

Because you steer by direction, your finger can stay outside the well and
does not hide the action.

### The enemies

| Enemy | Behaviour | Points |
|---|---|---|
| **Skitter** (green) | Climbs its lane and side-steps toward you. On the rim it crawls toward the ship. | 150 |
| **Brood** (orange) | Slow. When shot, or when it reaches the rim, it bursts into two skitters in the neighbouring lanes. | 250 |
| **Lancer** (red) | Stops part-way up and fires three bolts up its lane, then climbs on. You can shoot bolts down (25). | 350 |
| **Sower** (magenta) | Climbs, sinks back, and climbs again somewhere else, leaving **mines** behind it. Mines drift up and blow up at the rim. They also block your dive to the next well (50 each). | 300 |
| **Orbiter** (cyan) | Shielded: it takes two hits. It sweeps round the well as it climbs. | 500 |

- **Overload meter**: each kill charges it. When it is full, the next
  second-finger tap fires it.
- **Diving**: once the well is empty you plunge down your lane. A mine left
  in that lane destroys you, so shoot it on the way down or change lanes.
- **Ships**: you start with 3 and gain one every 20,000 points.
- **Wells**: there are 12 (Ring, Hexagon, Bloom, Pentagon, Trough, Star,
  Ribbon, Diamond, Chevron, Oval, Horseshoe, Zigzag). They repeat faster
  and in a new colour after each round of twelve.

## Building

You need a Mac with Xcode 15 or later and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
make test      # game-logic unit tests (swift test); also runs on Linux
make project   # generate Rimward.xcodeproj from project.yml
open Rimward.xcodeproj
```

In Xcode, choose your team under *Signing & Capabilities* (or set
`DEVELOPMENT_TEAM` in `project.yml`), then run on a simulator or device.
`make build` builds for the simulator from the command line, without
signing.

The Xcode project and `App/Info.plist` are generated, not committed: edit
`project.yml` instead.

## Layout

```
RimwardCore/                 Swift package: all the game, no UI framework
  Sources/RimwardCore/
    Vec2.swift               2D vectors
    SplitMix64.swift         seedable PRNG (reproducible games and tests)
    Tube.swift               the well: perspective, lanes, aiming
    TubeCatalog.swift        the 12 procedurally generated wells
    Entities.swift           enemies, ship, shots, bolts, mines, bursts
    Game.swift               rules and state machine, fixed-step update
    Render.swift             the vector render list (glyphs, camera zoom)
    SoundSynthesis.swift     every sound effect, synthesized
  Tests/RimwardCoreTests/    XCTest suites
App/                         the iOS app (UIKit + SpriteKit + AVFoundation)
  Sources/GameScene.swift    draws the render list as glowing lines; touch input; HUD
  Sources/SoundEngine.swift  plays the synthesized effects
  Resources/                 asset catalog (app icon)
tools/make-icon.py           renders the app icon (Python + Pillow)
project.yml                  XcodeGen project specification
```

The core is independent of the UI. The app calls `Game.step(dt:input:)` at
a fixed 120 Hz, draws `Game.renderStrokes()` (polylines in a normalized
[-1, 1] view space, tagged by colour), and turns `Game.drainEvents()` into
sound and haptics. This lets the rules be tested on any platform and makes
another front end (macOS, tvOS with a game controller) cheap to add.

## Licence

Copyright (C) 2026 Pascal J. Bourguignon.

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at your
option) any later version. See [LICENSE](LICENSE).
