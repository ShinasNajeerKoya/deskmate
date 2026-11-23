# Deskmate Hub for Windows

Tray app that sends this PC's data to the Deskmate phone app over Bluetooth LE.
Status: **preview, untested on real hardware.**

- Windows 10 (1809+) or 11, with a Bluetooth adapter that supports the **LE peripheral role**
  (many laptop adapters do; some USB dongles don't, in which case the tray menu says so).
- Built on GitHub Actions (`.github/workflows/deskmate-hub-windows.yml`); locally:
  `dotnet publish DeskmateHub -c Release -r win-x64 --self-contained -p:PublishSingleFile=true`.
