import AppKit
import ApplicationServices

/// Slack unread count from the badge on Slack's Dock icon (privacy mode:
/// a number only, never message text). Reading the Dock needs Accessibility
/// permission; without it, the phone's Slack tile stays empty.
final class SlackCollector {
    private(set) var problem: String?
    private var asked = false

    /// The badge number, 0 for no badge or a dot (unreads without a count), nil if unknown.
    func unread() -> Int? {
        if !AXIsProcessTrusted() {
            if !asked {
                asked = true
                // Shows the system prompt that opens Privacy & Security → Accessibility.
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
            }
            problem = "Allow Deskmate Hub in System Settings → Privacy & Security → Accessibility (for the Slack count)"
            return nil
        }
        problem = nil
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return nil }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        for list in children(of: app) {
            for item in children(of: list) {
                guard string(item, kAXTitleAttribute) == "Slack" else { continue }
                guard let badge = string(item, "AXStatusLabel"), !badge.isEmpty else { return 0 }
                return Int(badge.filter(\.isNumber)) ?? 0
            }
        }
        return nil  // Slack isn't in the Dock
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
