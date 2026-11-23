import AppKit
import SwiftUI

/// Kept alive for the whole run (the App struct can be recreated by SwiftUI).
let controller: HubController = {
    if CommandLine.arguments.contains("--dump") { HubController.dumpAndExit() }
    let c = HubController()
    c.start()
    return c
}()

@main
struct DeskmateHubApp: App {
    @ObservedObject private var model = controller.model

    var body: some Scene {
        MenuBarExtra {
            Text(model.statusLine)
            ForEach(model.problems, id: \.self) { problem in
                Text("⚠︎ " + problem)
            }
            Divider()
            if let code = model.pairingCode {
                Text("Wi-Fi pairing code: \(code.prefix(3)) \(code.suffix(3))")
                Text("Type it on the phone: Settings → Wi-Fi link (2 minutes)")
                if let address = model.localAddress { Text("This Mac's IP (if asked): \(address)") }
            } else {
                Button(model.wifiPaired ? "Pair another phone over Wi-Fi…" : "Pair a phone over Wi-Fi…") {
                    controller.pairOverWifi()
                }
            }
            Divider()
            switch model.claudeSetup {
            case .connected:
                Text("Claude usage connected")
            case .notConnected:
                Button("Connect Claude usage…") { controller.connectClaude() }
            case .otherStatusLine:
                Text("Claude limits: another status line is set up")
            }
            if let message = model.claudeMessage { Text(message) }
            Divider()
            Toggle("Open at Login", isOn: Binding(get: { model.openAtLogin }, set: { model.setOpenAtLogin($0) }))
            Divider()
            Text("Deskmate Hub \(model.version)")
            Button("Quit Deskmate Hub") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: model.connected ? "iphone.radiowaves.left.and.right" : "iphone.slash")
        }
    }
}
