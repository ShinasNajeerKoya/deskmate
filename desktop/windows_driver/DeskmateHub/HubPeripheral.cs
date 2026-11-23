using System.Text;
using System.Text.Json;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Storage.Streams;

namespace DeskmateHub;

/// <summary>
/// GATT server: advertises the Deskmate service, pushes messages to the phone and
/// receives the phone's writes (its name, later commands).
/// Needs a Bluetooth adapter that supports the LE peripheral role.
/// </summary>
sealed class HubPeripheral
{
    GattServiceProvider? _provider;
    GattLocalCharacteristic? _stats;
    byte[] _latest = Array.Empty<byte>();
    int _partId;
    readonly Dictionary<ulong, string> _names = new();

    /// <summary>Raised (on a background thread) when status, connection or phone name changes.</summary>
    public event Action? Changed;

    /// <summary>Raised when a phone subscribes, so the app can send the clock and power state.</summary>
    public event Action? PhoneSubscribed;

    public string Status { get; private set; } = "Starting…";
    public bool Ready { get; private set; }
    public bool Connected => _stats?.SubscribedClients.Count > 0;

    public string? PhoneName
    {
        get
        {
            if (_stats == null) return null;
            foreach (var c in _stats.SubscribedClients)
                if (_names.TryGetValue(c.Session.DeviceId.Id.GetHashCodeUlong(), out var n)) return n;
            return null;
        }
    }

    public async Task StartAsync()
    {
        try
        {
            var adapter = await BluetoothAdapter.GetDefaultAsync();
            if (adapter == null) { SetStatus("No Bluetooth adapter found"); return; }
            if (!adapter.IsLowEnergySupported || !adapter.IsPeripheralRoleSupported)
            {
                SetStatus("This PC's Bluetooth can't share data over Bluetooth LE");
                return;
            }

            var result = await GattServiceProvider.CreateAsync(Gatt.Service);
            if (result.Error != BluetoothError.Success) { SetStatus($"Bluetooth error: {result.Error}"); return; }
            _provider = result.ServiceProvider;

            var statsResult = await _provider.Service.CreateCharacteristicAsync(Gatt.Stats, new GattLocalCharacteristicParameters
            {
                CharacteristicProperties = GattCharacteristicProperties.Read | GattCharacteristicProperties.Notify,
                ReadProtectionLevel = GattProtectionLevel.Plain,
            });
            _stats = statsResult.Characteristic;
            _stats.ReadRequested += OnReadRequested;
            _stats.SubscribedClientsChanged += (_, _) =>
            {
                if (Connected) PhoneSubscribed?.Invoke();
                Changed?.Invoke();
            };

            var commandResult = await _provider.Service.CreateCharacteristicAsync(Gatt.Command, new GattLocalCharacteristicParameters
            {
                CharacteristicProperties = GattCharacteristicProperties.Write | GattCharacteristicProperties.WriteWithoutResponse,
                WriteProtectionLevel = GattProtectionLevel.Plain,
            });
            commandResult.Characteristic.WriteRequested += OnWriteRequested;

            _provider.StartAdvertising(new GattServiceProviderAdvertisingParameters { IsConnectable = true, IsDiscoverable = true });
            Ready = true;
            SetStatus("Waiting for your phone…");
        }
        catch (Exception e)
        {
            SetStatus($"Bluetooth unavailable: {e.Message}");
        }
    }

    /// <summary>Sends one JSON message to every subscribed phone.</summary>
    public async Task SendAsync(Dictionary<string, object> message)
    {
        var bytes = JsonSerializer.SerializeToUtf8Bytes(message);
        if (message.TryGetValue("t", out var t) && (string)t == "sys") _latest = bytes;
        if (_stats == null || !Connected) return;
        try
        {
            var max = _stats.SubscribedClients.Min(c => (int)c.MaxNotificationSize);
            if (bytes.Length <= max)
            {
                await _stats.NotifyValueAsync(ToBuffer(bytes));
                return;
            }
            // Too big for one packet: send base64 parts {"t":"part","id","i","n","d"}.
            _partId = (_partId + 1) % 10000;
            var text = Convert.ToBase64String(bytes);
            var size = Math.Max(8, max - 48);
            var count = (text.Length + size - 1) / size;
            for (var i = 0; i < count; i++)
            {
                var part = new Dictionary<string, object>
                {
                    ["t"] = "part", ["id"] = _partId, ["i"] = i, ["n"] = count,
                    ["d"] = text.Substring(i * size, Math.Min(size, text.Length - i * size)),
                };
                await _stats.NotifyValueAsync(ToBuffer(JsonSerializer.SerializeToUtf8Bytes(part)));
            }
        }
        catch
        {
            // A phone dropping mid-notify is normal; the next message tries again.
        }
    }

    async void OnReadRequested(GattLocalCharacteristic sender, GattReadRequestedEventArgs args)
    {
        var deferral = args.GetDeferral();
        try
        {
            var request = await args.GetRequestAsync();
            request?.RespondWithValue(ToBuffer(_latest));
        }
        finally { deferral.Complete(); }
    }

    async void OnWriteRequested(GattLocalCharacteristic sender, GattWriteRequestedEventArgs args)
    {
        var deferral = args.GetDeferral();
        try
        {
            var request = await args.GetRequestAsync();
            if (request == null) return;
            var reader = DataReader.FromBuffer(request.Value);
            var bytes = new byte[reader.UnconsumedBufferLength];
            reader.ReadBytes(bytes);
            if (request.Option == GattWriteOption.WriteWithResponse) request.Respond();

            using var doc = JsonDocument.Parse(Encoding.UTF8.GetString(bytes));
            var root = doc.RootElement;
            if (root.TryGetProperty("t", out var t) && t.GetString() == "hello" &&
                root.TryGetProperty("name", out var name) && !string.IsNullOrWhiteSpace(name.GetString()))
            {
                _names[args.Session.DeviceId.Id.GetHashCodeUlong()] = name.GetString()!.Trim();
                Changed?.Invoke();
            }
            // Commands ("t":"cmd") are handled in a later version.
        }
        catch
        {
            // Ignore malformed writes.
        }
        finally { deferral.Complete(); }
    }

    void SetStatus(string status)
    {
        Status = status;
        Changed?.Invoke();
    }

    static IBuffer ToBuffer(byte[] bytes)
    {
        var writer = new DataWriter();
        writer.WriteBytes(bytes);
        return writer.DetachBuffer();
    }
}

static class StringExtensions
{
    /// <summary>Stable key for a device id string (string.GetHashCode is randomised per run).</summary>
    public static ulong GetHashCodeUlong(this string s)
    {
        ulong hash = 14695981039346656037UL; // FNV-1a
        foreach (var ch in s) { hash ^= ch; hash *= 1099511628211UL; }
        return hash;
    }
}
