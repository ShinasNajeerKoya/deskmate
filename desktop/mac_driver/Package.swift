// swift-tools-version:5.9
import PackageDescription

// Deskmate Hub for macOS: a menu-bar app that sends data to the Deskmate phone app over BLE.
// Build the .app with scripts/build-app.sh; `swift run` works for development.
let package = Package(
    name: "DeskmateHub",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DeskmateHub",
            path: "Sources/DeskmateHub",
            exclude: ["Info.plist"],
            linkerSettings: [
                // Embed Info.plist so `swift run` gets a proper Bluetooth permission prompt too.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/DeskmateHub/Info.plist",
                ])
            ]
        )
    ]
)
