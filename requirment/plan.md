# PhoneDrop: Phone → Laptop Instant Transfer

A step-by-step plan: the problem, the approaches we considered, the one we chose, and how we build it.

---

## 1. The Problem

Every time I want to move something small from my phone to my laptop (a piece of text, a link, or an image of a few KB), I have to use WhatsApp, email, or some other app. It is slow and annoying for something so small.

**What I actually want:** type or share on the phone, and it shows up on the laptop. Nothing more.

**Why this is harder than it looks.** The transfer itself is easy. The friction is in the edges:

1. **Phone side:** how fast can I get something into the pipe? Ideally from the Share menu, with no login.
2. **Laptop side:** how does it arrive without me doing anything? Ideally straight into the clipboard.
3. **Finding the laptop:** how does the phone know which device to send to, especially when many devices share one WiFi?
4. **Network:** my laptop is usually connected to my phone's hotspot. It should work there, and ideally with no internet.

---

## 2. Goals and Non-Goals

**Goals (v1)**
- Phone → laptop only
- Text, links, and small images
- Works on the local network (phone hotspot or same WiFi), no internet needed
- Scan a QR code once, then never again
- Laptop: Windows. Phone app: Flutter

**Non-goals (for now)**
- Laptop → phone
- Sending from anywhere over the internet
- End-to-end encryption
- iPhone Share Extension

---

## 3. Approaches Considered

### Approach 0: Use an existing tool
Telegram Saved Messages, KDE Connect, LocalSend, PairDrop, ntfy.sh, Phone Link.
- Fastest way to solve it today.
- Decision: I want to build my own, so this is the fallback and a benchmark to compare against.

### Approach A: Local only (same WiFi or hotspot)
The laptop runs a small server. The phone sends to its address over the local network.
- Pros: simplest, private, free, no accounts, works offline
- Cons: both devices must be on the same network; the laptop's IP can change; some networks block device-to-device traffic

### Approach B: Cloud relay (works from anywhere)
Phone → server on the internet → laptop.
- Pros: works on any network, no IP problems
- Cons: needs hosting, auth, and privacy thinking; needs internet

### Approach C: Private network (Tailscale)
Both devices join a private network and behave as if on the same WiFi, anywhere.
- Pros: Approach A plus "from anywhere"
- Cons: third-party dependency; always-on app on the phone

---

## 4. Chosen Approach

**Build Approach A first, and design it so Approach B can be added later.**

Why:
- It is the easiest to build and fully offline.
- It matches my daily setup: laptop on the phone hotspot, so only two devices on the network.
- The message format stays separate from the transport (`{type, data}`), so moving to a cloud relay later means changing where we send, not rewriting the app.

---

## 5. Network Scenarios

### Scenario 1: Laptop on my phone's hotspot (daily setup)
- Only two devices, so no confusion about which is which.
- Traffic stays local and uses no mobile data.
- Phone is the gateway, with a fixed address (Android is usually `192.168.43.1`).
- The laptop's IP is handed out by the phone and rarely changes.
- Watch out: some phones enable client isolation on the hotspot. Test this first (Phase 0).

### Scenario 2: Both on a home or office router
- Many devices, and the laptop's IP may change.
- Some office or guest networks block device-to-device traffic entirely. If so, Approach A will not work there, and the cloud relay becomes the fallback.

---

## 6. Finding the Right Laptop

| Method | Role |
|---|---|
| **QR code pairing** | Main method. Laptop shows a QR with its address and a secret key. Scan once, the phone saves both. |
| **Secret key on every request** | Solves "many devices on the WiFi". Any other machine rejects the request. |
| **Subnet scan fallback** | If the saved IP stops working, the phone checks `.1` to `.254` on the port and asks "are you my laptop?" using the key. |
| **Rescan QR** | Last resort, takes about 5 seconds. |
| mDNS name (`mylaptop.local`) | Optional bonus, unreliable on Android. |
| UDP/mDNS auto-discovery | Later upgrade, needs the native app (`nsd`). |

**Do I scan the QR every time? No.** Only on first setup, after a reset, or if the IP changes and the auto-scan also fails.

---

## 7. Architecture

```
Phone (Flutter app)                    Laptop (Windows, Node.js)
+------------------+   POST /send      +----------------------+
| Type / Paste /   | ----------------> | Express server :3000 |
| Share menu       |  X-Key: <secret>  | - check key          |
| Saved: IP + key  |  {type, data}     | - copy to clipboard  |
+------------------+                   | - save images        |
        ^                              | - show notification  |
        |  scan QR once                +----------------------+
        +---- QR: http://<ip>:3000/?key=<secret> <---- shown on laptop
```

---

## 8. What the Laptop Side Looks Like

A **system tray app** (also called a background app or desktop companion), like Dropbox or Phone Link. Not a web page.

- Tray icon in the bottom-right of Windows. Right-click: Show QR, History, Quit.
- Pop-up notification when something arrives.
- Text and links are copied to the clipboard automatically, so just press Ctrl+V.
- Images are saved to `Downloads/PhoneDrop`.

**Stages:** v1 terminal script → v2 tray app (Electron or Tauri) → v3 auto-start with Windows.

---

## 9. Tech Stack

**Laptop (Node.js)**
| Purpose | Package |
|---|---|
| HTTP server | `express` |
| Clipboard | `clipboardy` |
| Pairing QR | `qrcode-terminal` (v1) |
| Notifications | `node-notifier` |
| Tray app (later) | Electron or Tauri |

**Phone (Flutter)**
| Purpose | Package |
|---|---|
| Scan QR | `mobile_scanner` |
| Send to laptop | `http` |
| Save IP + key | `shared_preferences` |
| Share menu | `receive_sharing_intent` |
| Pick images | `image_picker` |
| Auto-discovery (later) | `nsd` |

---

## 10. Protocol

**Request**
```
POST /send
Header: X-Key: <secret>
Body (JSON): { "type": "text" | "link" | "image", "data": "...", "ts": 1700000000 }
```
- For `image`, `data` is base64 (small images only in v1).

**Responses:** `200` received, `401` wrong key, `400` bad payload.

**Health check:** `GET /ping` with the key, so the phone can verify "is this my laptop?"

---

## 11. Build Phases

### Phase 0: Feasibility check (15 min)
- [ ] Install Node.js on the laptop
- [ ] Run a test server, open `http://<laptop-ip>:3000` from the phone browser
- [ ] If it loads over the hotspot, the approach works. If not, check client isolation and the firewall.

### Phase 1: Laptop server v1 (terminal)
- [ ] Express server with `POST /send` and `GET /ping`
- [ ] Generate and check the secret key
- [ ] Copy text and links to the clipboard
- [ ] Save images to `Downloads/PhoneDrop`
- [ ] Show the pairing QR in the terminal
- [ ] Windows Firewall: allow inbound port 3000 on private networks

### Phase 2: Flutter app v1
- [ ] QR scan screen, save IP and key
- [ ] Main screen: text box, Paste, Send
- [ ] Send text and links
- [ ] Success and error feedback
- [ ] Android: camera permission, allow plain HTTP to local IPs

### Phase 3: Share menu and images
- [ ] App appears in the Android Share sheet
- [ ] Share text, link, or image straight to the laptop
- [ ] Image picker, base64 send, size limit and compression

### Phase 4: Reliability
- [ ] Subnet scan when the saved IP fails
- [ ] Recent history and resend on the phone
- [ ] Timeouts and retry

### Phase 5: Laptop polish
- [ ] Tray app with Show QR, History, Quit
- [ ] Desktop notification on receive
- [ ] Auto-start with Windows
- [ ] Installer

### Phase 6: Future
- [ ] Laptop → phone (WebSocket)
- [ ] Cloud relay for sending from anywhere
- [ ] End-to-end encryption
- [ ] iPhone Share Extension

---

## 12. Risks and Fixes

| Risk | Fix |
|---|---|
| Hotspot blocks device-to-device traffic | Test in Phase 0; fall back to router WiFi or cloud relay |
| Windows Firewall blocks the port | Add an inbound rule for private networks |
| Android blocks plain `http://` | Allow cleartext traffic for local IPs |
| Laptop IP changes | Subnet scan, then QR rescan |
| Office or guest WiFi isolates devices | Use hotspot, or add cloud relay later |
| iPhone Share menu needs a native extension | Android first, iOS later |
| Others on the network try the port | Secret key on every request; encryption later |

---

## 13. Folder Structure

```
phonedrop/
├── plan.md
├── laptop/            # Node.js server (later a tray app)
│   ├── server.js
│   ├── config.json    # generated secret key
│   └── package.json
└── mobile/            # Flutter app
    ├── lib/
    │   ├── main.dart
    │   ├── pairing_screen.dart
    │   ├── send_screen.dart
    │   └── api.dart
    └── pubspec.yaml
```

---

## 14. Definition of Done (v1)

- Scan the QR once and it stays paired
- Type or share text/link on the phone, and it is in the laptop clipboard within about a second
- A small image appears in `Downloads/PhoneDrop`
- Works with no internet, on the phone hotspot
- A wrong key is rejected

---

## 15. Open Questions

- Is the phone Android or iPhone? (affects the Share menu)
- Maximum image size to support?
- Should images also go to the clipboard, or only to the folder?

---

## 16. Next Step

Do Phase 0, then write `laptop/server.js` (Phase 1), then start the Flutter app.
