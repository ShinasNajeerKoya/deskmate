// swift-tools-version:5.9
import PackageDescription

// Step 1 spike: a command-line BLE peripheral that streams CPU %.
// It becomes the menu-bar app later. The Info.plist is embedded in the binary
// so macOS shows a proper Bluetooth permission prompt.
let package = Package(
    name: "DeskmateMac",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DeskmateMac",
            path: "Sources/DeskmateMac",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/DeskmateMac/Info.plist",
                ])
            ]
        )
    ]
)
