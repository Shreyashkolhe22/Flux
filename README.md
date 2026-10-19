# Flux

Send text, links and images from your Android phone to your Windows laptop, instantly.
Local network only. No cloud, no account, no internet needed.

Type or share something on the phone, and your laptop shows a notification
**"Received from phone. Copied. Ready to paste (Ctrl+V)."** Text and links go straight
to the clipboard; images and files (PDFs, documents, zips, up to 100 MB) are saved to
`Downloads\Flux`.

## Install

Download the files from the [latest release](../../releases/latest):

| Device | File | Steps |
|---|---|---|
| Windows laptop | `Flux-Setup-x.y.z.exe` | Run it. It installs Flux, opens the firewall for your local network, starts with Windows, and shows a QR code. |
| Android phone | `app-arm64-v8a-release.apk` | Open it and allow "install unknown apps" when asked. Use this one for any phone from about 2017 on. Very old 32-bit phones need `app-armeabi-v7a-release.apk` instead. |

Windows may show a SmartScreen warning because the installer is not code-signed:
click **More info**, then **Run anyway**.

## Pair (once)

1. Put the laptop and phone on the same network. A phone hotspot is the easiest:
   turn it on and connect the laptop to it. Same home WiFi also works.
2. Laptop: the Flux QR window opens after install (later: click the Flux tray icon).
3. Phone: open Flux, tap **Scan QR to pair**, scan the code.

After that it stays paired. If the laptop's address changes, the app finds it again by itself.

## Use

- Type or paste in the app and tap the red arrow.
- Or, in any app (Chrome, Gallery, Notes), tap **Share**, then **Flux**.
- Pick a photo with **Image**, take one with **Camera**, or send any file (PDF, document, zip) with **File**.
  You can also share files from any app. Files up to 100 MB; a file with the same name is never overwritten.
- **One-tap clipboard send:** copy something in any app, then tap the Flux **home-screen widget**
  or the **Send clipboard** tile in the pull-down panel. In Flux, open Settings, then Shortcuts, to add
  either one. Android shows a small "pasted from your clipboard" notice when this happens; that is
  Android's own privacy message. Widget and tile send text and links.
- Failed sends stay in Recent. Tap one to retry.

## Tray menu (laptop)

Show QR to pair, History (click an item to copy it again or show a file in its folder), Open received files folder,
Start with Windows, Reset pairing key, Quit.

## Troubleshooting

- **Phone says it can't find the laptop:** both must be on the same network, and
  Flux must be running on the laptop (tray icon). If the firewall rule is missing, reinstall Flux
  (or, when running from source, run the `netsh` command in `laptop/README.md` as administrator).
  Some office and guest networks block devices from talking to each other; use your phone hotspot there.
- **Works in the phone browser at `http://<laptop-ip>:3000/ping` but not in the app:**
  turn mobile data off on the phone and try again.
- **Port 3000 is in use:** close the other program using it.
- **Changed networks or reset the key:** in the app, open Devices, tap Forget, and scan the QR again.

## Security

Flux is designed for your own devices on a network you trust (your hotspot or home WiFi).

- A random 192-bit key from the QR code is required on every send.
- Traffic is plain HTTP on the local network and is not encrypted. Do not use Flux on
  public or shared WiFi.
- Received text replaces your clipboard immediately. Anyone who has your pairing key can do the same,
  so use **Reset pairing key** in the tray menu if you shared the QR code.

## How it works

```
Phone (Flutter)  --POST /send, X-Key-->  Laptop (Electron + Express, port 3000)
                                          copy to clipboard / save image / notify
```

- `lib/`, `android/`: the Flutter app
- `laptop/`: the Windows receiver (`core.js` server, `main.js` tray app, `server.js` terminal mode)

## Build from source

```
# Laptop installer
cd laptop
npm install
npm run dist        # writes laptop/dist/Flux-Setup-x.y.z.exe
npm run tray        # run the tray app without installing

# Phone app
flutter pub get
flutter build apk --release --split-per-abi   # one small APK per CPU type
```

Releases are built automatically when a tag like `v1.0.0` is pushed
(see `.github/workflows/release.yml`).
