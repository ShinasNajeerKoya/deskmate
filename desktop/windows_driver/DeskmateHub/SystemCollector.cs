using System.Diagnostics;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;

namespace DeskmateHub;

/// <summary>Task Manager–style numbers for the phone's System page.</summary>
sealed class SystemCollector
{
    [StructLayout(LayoutKind.Sequential)]
    struct MemoryStatusEx
    {
        public uint Length, MemoryLoad;
        public ulong TotalPhys, AvailPhys, TotalPageFile, AvailPageFile, TotalVirtual, AvailVirtual, AvailExtendedVirtual;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GlobalMemoryStatusEx(ref MemoryStatusEx status);

    readonly CpuSampler _cpu = new();
    (long down, long up, DateTime at)? _lastNet;
    Dictionary<int, TimeSpan> _lastProc = new();
    DateTime? _lastProcAt;

    public SystemCollector() => _cpu.Sample();

    public Dictionary<string, object> Collect()
    {
        var m = new Dictionary<string, object> { ["t"] = "sys" };
        var cpu = _cpu.Sample();
        if (cpu is not null) m["cpu"] = Math.Round(cpu.Value, 1);

        var mem = new MemoryStatusEx { Length = (uint)Marshal.SizeOf<MemoryStatusEx>() };
        if (GlobalMemoryStatusEx(ref mem))
        {
            var total = mem.TotalPhys / 1073741824.0;
            m["mem"] = Math.Round((double)mem.MemoryLoad, 1);
            m["memUsed"] = Math.Round((mem.TotalPhys - mem.AvailPhys) / 1073741824.0, 1);
            m["memTotal"] = Math.Round(total);
        }
        m["cores"] = Environment.ProcessorCount;
        m["onPower"] = SystemInformation.PowerStatus.PowerLineStatus != PowerLineStatus.Offline;
        if (cpu is not null) m["energy"] = cpu < 25 ? "Low" : cpu < 60 ? "Medium" : "High";

        try
        {
            var system = new DriveInfo(Path.GetPathRoot(Environment.SystemDirectory) ?? "C:\\");
            m["diskFree"] = Math.Round(system.AvailableFreeSpace / 1e9);
        }
        catch { }

        var net = NetworkRates();
        if (net is not null) { m["down"] = Math.Round(net.Value.down, 1); m["up"] = Math.Round(net.Value.up, 1); }

        var procs = TopProcesses();
        if (procs.Count > 0) m["procs"] = procs;
        return m;
    }

    (double down, double up)? NetworkRates()
    {
        long down = 0, up = 0;
        foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (nic.OperationalStatus != OperationalStatus.Up || nic.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
            var s = nic.GetIPv4Statistics();
            down += s.BytesReceived;
            up += s.BytesSent;
        }
        var now = DateTime.UtcNow;
        var last = _lastNet;
        _lastNet = (down, up, now);
        if (last is null) return null;
        var seconds = (now - last.Value.at).TotalSeconds;
        if (seconds <= 0) return null;
        return (Math.Max(0, down - last.Value.down) / seconds / 1000, Math.Max(0, up - last.Value.up) / seconds / 1000);
    }

    /// <summary>Top 5 processes by CPU (% of one core), merged by name.</summary>
    List<object[]> TopProcesses()
    {
        var now = DateTime.UtcNow;
        var times = new Dictionary<int, TimeSpan>();
        var usage = new Dictionary<string, double>();
        var elapsed = _lastProcAt is null ? 0 : (now - _lastProcAt.Value).TotalMilliseconds;
        foreach (var p in Process.GetProcesses())
        {
            try
            {
                var t = p.TotalProcessorTime;
                times[p.Id] = t;
                if (elapsed > 0 && _lastProc.TryGetValue(p.Id, out var before) && t >= before)
                {
                    var pct = (t - before).TotalMilliseconds / elapsed * 100;
                    if (pct >= 0.5) usage[p.ProcessName] = usage.GetValueOrDefault(p.ProcessName) + pct;
                }
            }
            catch { /* access denied for some system processes */ }
            finally { p.Dispose(); }
        }
        _lastProc = times;
        _lastProcAt = now;
        return usage.OrderByDescending(kv => kv.Value).Take(5)
            .Select(kv => new object[] { kv.Key.Length > 24 ? kv.Key[..24] : kv.Key, Math.Round(kv.Value, 1) }).ToList();
    }
}
