import Darwin
import Foundation
import IOKit
import IOKit.ps

/// Activity Monitor–style numbers for the phone's System page:
/// CPU, memory, energy, disk I/O and free space, network, top processes.
final class SystemCollector {
    private let cpu = CPUSampler()
    private var lastDisk: (read: UInt64, write: UInt64, at: Date)?
    private var lastNet: (down: UInt64, up: UInt64, at: Date)?
    private var lastProcTimes: [pid_t: UInt64] = [:]
    private var lastProcAt: Date?

    init() { _ = cpu.sample() }

    /// One `sys` message (without seq). Called once a second.
    func collect() -> [String: Any] {
        var m: [String: Any] = ["t": "sys"]
        if let c = cpu.sample() { m["cpu"] = round1(c) }

        let total = Double(ProcessInfo.processInfo.physicalMemory)
        if let used = memoryUsed() {
            m["mem"] = round1(used / total * 100)
            m["memUsed"] = round1(used / 1_073_741_824)
        }
        m["memTotal"] = (total / 1_073_741_824).rounded()
        m["cores"] = ProcessInfo.processInfo.activeProcessorCount

        let onPower = isOnPower()
        m["onPower"] = onPower
        if let c = (m["cpu"] as? NSNumber)?.doubleValue { m["energy"] = c < 25 ? "Low" : (c < 60 ? "Medium" : "High") }

        if let free = diskFreeGB() { m["diskFree"] = free.rounded() }
        if let rate = diskRateMBs() { m["disk"] = round1(rate) }
        if let (down, up) = networkRatesKBs() {
            m["down"] = round1(down)
            m["up"] = round1(up)
        }
        let procs = topProcesses()
        if !procs.cpu.isEmpty { m["procs"] = procs.cpu }
        if !procs.memory.isEmpty { m["mprocs"] = procs.memory }
        return m
    }

    // MARK: Memory

    /// Like Activity Monitor's "Memory Used": app memory + wired + compressed.
    private func memoryUsed() -> Double? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let page = Double(vm_kernel_page_size)
        let app = Double(stats.internal_page_count) - Double(stats.purgeable_count)
        let wired = Double(stats.wire_count)
        let compressed = Double(stats.compressor_page_count)
        return (app + wired + compressed) * page
    }

    // MARK: Power

    private func isOnPower() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        else { return true }  // desktops have no battery
        return type == kIOPMACPowerKey
    }

    // MARK: Disk

    private func diskFreeGB() -> Double? {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return Double(bytes) / 1_000_000_000
    }

    /// Read + write throughput across all disks, MB/s.
    private func diskRateMBs() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator)
                == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var read: UInt64 = 0, write: UInt64 = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let props = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] {
                read += (props["Bytes (Read)"] as? UInt64) ?? 0
                write += (props["Bytes (Write)"] as? UInt64) ?? 0
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        let now = Date()
        defer { lastDisk = (read, write, now) }
        guard let last = lastDisk else { return nil }
        let seconds = now.timeIntervalSince(last.at)
        guard seconds > 0 else { return nil }
        return Double((read &- last.read) &+ (write &- last.write)) / seconds / 1_000_000
    }

    // MARK: Network

    /// Down/up across physical interfaces, KB/s.
    private func networkRatesKBs() -> (Double, Double)? {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return nil }
        defer { freeifaddrs(addrs) }
        var down: UInt64 = 0, up: UInt64 = 0
        var p: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = p {
            let name = String(cString: ifa.pointee.ifa_name)
            if ifa.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               name.hasPrefix("en") || name.hasPrefix("pdp_ip"),
               let data = ifa.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                down += UInt64(data.pointee.ifi_ibytes)
                up += UInt64(data.pointee.ifi_obytes)
            }
            p = ifa.pointee.ifa_next
        }
        let now = Date()
        defer { lastNet = (down, up, now) }
        guard let last = lastNet else { return nil }
        let seconds = now.timeIntervalSince(last.at)
        guard seconds > 0 else { return nil }
        // Counters are 32-bit per interface and can wrap; ignore negative jumps.
        let d = down >= last.down ? Double(down - last.down) : 0
        let u = up >= last.up ? Double(up - last.up) : 0
        return (d / seconds / 1000, u / seconds / 1000)
    }

    // MARK: Processes

    /// Top 5 processes by CPU (% of one core, like Activity Monitor) and top 5 by memory (resident MB),
    /// names shortened. Helpers of the same app are added together.
    private func topProcesses() -> (cpu: [[Any]], memory: [[Any]]) {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return ([], []) }
        var pids = [pid_t](repeating: 0, count: Int(count) + 32)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard filled > 0 else { return ([], []) }

        let now = Date()
        var times: [pid_t: UInt64] = [:]
        var usage: [(String, Double)] = []
        var resident: [String: UInt64] = [:]
        let elapsedNs = lastProcAt.map { now.timeIntervalSince($0) * 1_000_000_000 } ?? 0

        for pid in pids.prefix(Int(filled)) where pid > 0 {
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { continue }
            let total = info.pti_total_user + info.pti_total_system
            times[pid] = total
            let name = processName(pid)
            resident[name, default: 0] += info.pti_resident_size
            guard elapsedNs > 0, let before = lastProcTimes[pid], total >= before else { continue }
            let percent = Double(total - before) * machTimeToNs / elapsedNs * 100
            if percent >= 0.5 { usage.append((name, percent)) }
        }
        lastProcTimes = times
        lastProcAt = now

        // Merge helpers of the same app (e.g. "Google Chrome Helper (Renderer)" → "Google Chrome").
        var merged: [String: Double] = [:]
        for (name, value) in usage { merged[name, default: 0] += value }
        let cpu = merged.sorted { $0.value > $1.value }.prefix(5).map { [String($0.key.prefix(24)), round1($0.value)] as [Any] }
        let memory = resident.sorted { $0.value > $1.value }.prefix(5)
            .map { [String($0.key.prefix(24)), Int(Double($0.value) / 1_048_576)] as [Any] }
        return (cpu, memory)
    }

    private func processName(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buffer, UInt32(buffer.count))
        var name = String(cString: buffer)
        if let range = name.range(of: " Helper") { name = String(name[..<range.lowerBound]) }
        return name.isEmpty ? "pid \(pid)" : name
    }

    /// pti_total_* are in Mach absolute time units on Apple silicon.
    private let machTimeToNs: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom)
    }()

    private func round1(_ v: Double) -> NSDecimalNumber { dec(v) }
}
