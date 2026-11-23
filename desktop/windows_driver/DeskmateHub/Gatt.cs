namespace DeskmateHub;

/// <summary>Shared BLE contract. Keep in sync with lib/ble/gatt.dart and desktop/mac_driver (GATT.swift).</summary>
static class Gatt
{
    public static readonly Guid Service = Guid.Parse("CC8A9226-538A-41AA-B390-85DB92127C62");

    /// <summary>Hub → phone. Notify + read. UTF-8 JSON messages with a topic "t".</summary>
    public static readonly Guid Stats = Guid.Parse("46ABD5B3-C525-463B-9E0A-5EB81163CCBB");

    /// <summary>Phone → Hub. Write. UTF-8 JSON, e.g. {"t":"hello","name":"…"}.</summary>
    public static readonly Guid Command = Guid.Parse("58DB6A63-A4AB-4A47-A369-966CAF61956F");
}
