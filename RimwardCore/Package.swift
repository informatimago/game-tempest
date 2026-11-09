// swift-tools-version:5.9
// Rimward -- an original vector tube shooter for iOS.
// Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later (see ../LICENSE).

import PackageDescription

let package = Package(
    name: "RimwardCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "RimwardCore", targets: ["RimwardCore"]),
    ],
    targets: [
        .target(name: "RimwardCore"),
        .testTarget(name: "RimwardCoreTests", dependencies: ["RimwardCore"]),
    ]
)
