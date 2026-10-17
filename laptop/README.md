# Flux laptop receiver

Receives text, links and images from the Flux phone app over your local network.

## Setup (once)
1. `npm install`
2. Allow the port in Windows Firewall (admin PowerShell):
   `netsh advfirewall firewall add rule name="Flux" dir=in action=allow protocol=TCP localport=3000`
3. Set your hotspot / WiFi network profile to **Private** (Settings > Network & internet).

## Run
- **Tray app (recommended):** `npm run tray`, or double-click `start-flux.bat`.
  Tray icon: Show QR, History, Open images folder, Start with Windows, Reset pairing key, Quit.
  The QR window opens on first launch. Click the tray icon to open it again.
- **Terminal:** `node server.js` (add `--reset` for a new key). Do not run both at once, they share port 3000.

Text and links go to the clipboard, images to `Downloads\Flux`.
