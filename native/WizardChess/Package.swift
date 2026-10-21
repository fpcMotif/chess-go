// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "WizardChess",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "WizardChess", targets: ["WizardChess"])
  ],
  targets: [
    .target(name: "ChessCore"),
    .executableTarget(
      name: "WizardChess",
      dependencies: ["ChessCore"],
      resources: [.process("Art")],
      swiftSettings: [.defaultIsolation(MainActor.self)]
    ),
    .testTarget(name: "ChessCoreTests", dependencies: ["ChessCore"]),
  ]
)
