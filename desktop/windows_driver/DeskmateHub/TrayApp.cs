using Microsoft.Win32;

namespace DeskmateHub;

/// <summary>
/// The whole UI: a tray icon whose menu shows the connection ("Connected to …"),
/// "Open at login" and Quit. All the details are shown on the phone.
/// </summary>
sealed class TrayApp : ApplicationContext
{
    readonly NotifyIcon _icon;
    readonly ToolStripMenuItem _status = new("Starting…") { Enabled = false };
    readonly ToolStripMenuItem _login = new("Open at login") { CheckOnClick = true };
    readonly HubPeripheral _hub = new();
    readonly SystemCollector _system = new();
    readonly SynchronizationContext _ui;
    readonly System.Windows.Forms.Timer _cpuTimer = new() { Interval = 2000 }; // every 2 s: the radio also streams Bluetooth audio
    readonly System.Windows.Forms.Timer _clockTimer = new() { Interval = 60 * 60 * 1000 };
    int _seq;
    bool _asleep;

    public TrayApp()
    {
        _ui = SynchronizationContext.Current ?? new WindowsFormsSynchronizationContext();

        LoginItem.EnableOnFirstLaunch();
        _login.Checked = LoginItem.IsEnabled;
        _login.CheckedChanged += (_, _) => LoginItem.Set(_login.Checked);

        var version = typeof(TrayApp).Assembly.GetName().Version?.ToString(3) ?? "dev";
        var menu = new ContextMenuStrip();
        menu.Items.Add(_status);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(_login);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem($"Deskmate Hub {version}") { Enabled = false });
        menu.Items.Add(new ToolStripMenuItem("Quit Deskmate Hub", null, (_, _) => ExitThread()));

        _icon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "Deskmate Hub",
            ContextMenuStrip = menu,
            Visible = true,
        };

        _hub.Changed += () => _ui.Post(_ => UpdateStatus(), null);
        _hub.PhoneSubscribed += () => { _ = SendTimeAsync(); _ = SendPowerAsync(); };

        // Sleep/lock → night clock on the phone; wake/unlock → board again.
        SystemEvents.PowerModeChanged += (_, e) =>
        {
            if (e.Mode == PowerModes.Suspend) SetAsleep(true);
            else if (e.Mode == PowerModes.Resume) SetAsleep(false);
        };
        SystemEvents.SessionSwitch += (_, e) =>
        {
            if (e.Reason == SessionSwitchReason.SessionLock) SetAsleep(true);
            else if (e.Reason == SessionSwitchReason.SessionUnlock) SetAsleep(false);
        };

        _cpuTimer.Tick += async (_, _) => await SendSystemAsync();
        _clockTimer.Tick += async (_, _) => await SendTimeAsync();
        _cpuTimer.Start();
        _clockTimer.Start();

        _ = _hub.StartAsync();
    }

    void UpdateStatus()
    {
        var text = !_hub.Ready ? _hub.Status
            : _hub.Connected ? $"Connected to {_hub.PhoneName ?? "your phone"}"
            : _hub.Status;
        _status.Text = text;
        // Tray tooltips are limited to 63 characters.
        var tip = "Deskmate Hub · " + text;
        _icon.Text = tip.Length > 63 ? tip[..63] : tip;
    }

    async Task SendSystemAsync()
    {
        if (!_hub.Connected) return;
        var m = _system.Collect();
        _seq++;
        m["seq"] = _seq;
        await _hub.SendAsync(m);
    }

    /// <summary>Clock sync: the phone has no network time, so it uses this PC's clock and time zone.</summary>
    Task SendTimeAsync() => _hub.SendAsync(new()
    {
        ["t"] = "time",
        ["ts"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
        ["tz"] = (int)TimeZoneInfo.Local.GetUtcOffset(DateTime.UtcNow).TotalMinutes,
    });

    Task SendPowerAsync() => _hub.SendAsync(new() { ["t"] = "power", ["asleep"] = _asleep });

    void SetAsleep(bool asleep)
    {
        if (_asleep == asleep) return;
        _asleep = asleep;
        _ = SendPowerAsync();
    }

    protected override void ExitThreadCore()
    {
        _icon.Visible = false;
        _icon.Dispose();
        base.ExitThreadCore();
    }
}
