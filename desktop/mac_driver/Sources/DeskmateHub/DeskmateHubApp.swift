import AppKit
import SwiftUI

/// Kept alive for the whole run (the App struct can be recreated by SwiftUI).
let controller: HubController = {
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
