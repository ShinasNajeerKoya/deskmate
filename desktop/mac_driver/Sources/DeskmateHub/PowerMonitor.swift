import AppKit

/// Tells the phone when the Mac sleeps or locks (night clock) and wakes or unlocks.
final class PowerMonitor {
    private let onChange: (_ asleep: Bool) -> Void
    private var tokens: [NSObjectProtocol] = []

    init(onChange: @escaping (_ asleep: Bool) -> Void) {
        self.onChange = onChange
        let ws = NSWorkspace.shared.notificationCenter
        let dist = DistributedNotificationCenter.default()
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            tokens.append(ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.onChange(true) })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            tokens.append(ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.onChange(false) })
        }
        tokens.append(dist.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.onChange(true)
        })
        tokens.append(dist.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.onChange(false)
        })
    }
}
