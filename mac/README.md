# Deskmate Mac (step 1 spike)

Command-line BLE peripheral that streams CPU % to the phone once a second.
It becomes the menu-bar app later.

```sh
cd mac
swift run
```

The first run asks for Bluetooth permission for the app running it (Terminal or VS Code).
If you see "permission denied", allow it in System Settings → Privacy & Security → Bluetooth.

BLE contract: [Sources/DeskmateMac/GATT.swift](Sources/DeskmateMac/GATT.swift), mirrored in `lib/ble/gatt.dart`.
