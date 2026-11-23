using System.Runtime.InteropServices;

namespace DeskmateHub;

/// <summary>Whole-machine CPU usage from GetSystemTimes deltas (like Task Manager's total).</summary>
sealed class CpuSampler
{
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetSystemTimes(out long idle, out long kernel, out long user);

    long _idle, _kernel, _user;
    bool _primed;

    /// <summary>0–100, or null on the first call (no delta yet).</summary>
    public double? Sample()
    {
        if (!GetSystemTimes(out var idle, out var kernel, out var user)) return null;
        var dIdle = idle - _idle;
        var dTotal = (kernel - _kernel) + (user - _user); // kernel time includes idle time
        (_idle, _kernel, _user) = (idle, kernel, user);
        if (!_primed) { _primed = true; return null; }
        if (dTotal <= 0) return 0;
        return Math.Clamp((1.0 - (double)dIdle / dTotal) * 100.0, 0, 100);
    }
}
