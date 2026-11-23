import Foundation

// Step 1 spike: stream CPU % to the phone once a second.

// Keep the timer punctual (no App Nap / timer coalescing), but still let the Mac sleep:
// the phone switches to its night clock when the link drops.
let activity = ProcessInfo.processInfo.beginActivity(
    options: .userInitiatedAllowingIdleSystemSleep,
    reason: "Streaming stats to Deskmate")
_ = activity

let peripheral = Peripheral()
let sampler = CPUSampler()
_ = sampler.sample()  // prime the delta

var seq = 0
var lastCPU = 0.0

let tick = Timer(timeInterval: 1.0, repeats: true) { _ in
    guard let cpu = sampler.sample() else { return }
    seq += 1
    lastCPU = (cpu * 10).rounded() / 10
    let payload: [String: Any] = ["t": "sys", "seq": seq, "cpu": lastCPU, "ts": Int(Date().timeIntervalSince1970)]
    if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) {
        peripheral.send(data)
    }
    if seq % 10 == 0 {
        log(String(format: "cpu %5.1f%%  seq %d  phones %d", lastCPU, seq, peripheral.subscriberCount))
    }
}
tick.tolerance = 0.05
RunLoop.main.add(tick, forMode: .common)

log("Deskmate Mac spike starting. Ctrl-C to stop.")
RunLoop.main.run()
