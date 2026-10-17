'use strict';
// Flux tray app (Electron). Run with `npm run tray`.
const { app, Tray, Menu, BrowserWindow, Notification, clipboard, nativeImage, shell, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');
const QRCode = require('qrcode');
const { createFlux } = require('./core');

if (!app.requestSingleInstanceLock()) app.quit();

const HISTORY_MAX = 10;
const history = [];
let tray = null;
let qrWindow = null;
let flux = null;

// Dev runs share the terminal script's config.json so the phone stays paired.
// An installed build keeps it in the user profile instead.
const configDir = app.isPackaged ? app.getPath('userData') : __dirname;
const settingsPath = path.join(app.getPath('userData'), 'settings.json');

function readSettings() {
  try {
    return JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
  } catch (_) {
    return {};
  }
}

function writeSettings(patch) {
  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  fs.writeFileSync(settingsPath, JSON.stringify({ ...readSettings(), ...patch }));
}

// Tray icon drawn in code (red dot with a white rim) so no asset file is needed.
function makeIcon() {
  const size = 32;
  const buf = Buffer.alloc(size * size * 4);
  const c = (size - 1) / 2;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const d = Math.hypot(x - c, y - c);
      const i = (y * size + x) * 4;
      let rgba = null;
      if (d <= 10) rgba = [0xd7, 0x19, 0x21, 255]; // red
      else if (d <= 13) rgba = [255, 255, 255, 255]; // rim
      if (rgba) {
        buf[i] = rgba[2]; // BGRA
        buf[i + 1] = rgba[1];
        buf[i + 2] = rgba[0];
        buf[i + 3] = rgba[3];
      }
    }
  }
  return nativeImage.createFromBitmap(buf, { width: size, height: size }).resize({ width: 16, height: 16 });
}

// The Flux logo, with the drawn red dot as a fallback if the file is missing.
function loadTrayIcon() {
  const img = nativeImage.createFromPath(path.join(__dirname, 'build', 'tray.png'));
  return img.isEmpty() ? makeIcon() : img.resize({ width: 16, height: 16, quality: 'best' });
}

function openAtLogin() {
  return app.getLoginItemSettings().openAtLogin;
}

function setOpenAtLogin(enabled) {
  // In dev the executable is electron.exe, which needs the app path as an argument.
  app.setLoginItemSettings({
    openAtLogin: enabled,
    path: process.execPath,
    args: app.isPackaged ? [] : [path.resolve(__dirname)],
  });
}

function ago(ts) {
  const s = Math.floor((Date.now() - ts) / 1000);
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  return `${Math.floor(s / 3600)} h ago`;
}

function buildMenu() {
  const items = history.length
    ? history.map((h) => ({
        label: `${h.type === 'image' ? '[img] ' : ''}${h.preview.replace(/\s+/g, ' ').slice(0, 40)}  (${ago(h.at)})`,
        click: () => {
          if (h.file) shell.showItemInFolder(h.file);
          else clipboard.writeText(h.full);
        },
      }))
    : [{ label: 'Nothing received yet', enabled: false }];

  return Menu.buildFromTemplate([
    { label: 'Show QR to pair', click: showQr },
    { label: 'History (click to copy / open)', submenu: items },
    { label: 'Open images folder', click: () => { fs.mkdirSync(flux.saveDir, { recursive: true }); shell.openPath(flux.saveDir); } },
    { type: 'separator' },
    {
      label: 'Start with Windows',
      type: 'checkbox',
      checked: openAtLogin(),
      click: (m) => setOpenAtLogin(m.checked),
    },
    {
      label: 'Reset pairing key...',
      click: async () => {
        const r = await dialog.showMessageBox({
          type: 'warning',
          buttons: ['Reset', 'Cancel'],
          defaultId: 1,
          message: 'Reset the pairing key?',
          detail: 'Your phone will stop working until you scan the new QR code.',
        });
        if (r.response === 0) {
          flux.resetKey();
          showQr();
        }
      },
    },
    { type: 'separator' },
    { label: 'Quit Flux', click: () => app.quit() },
  ]);
}

function refreshTray() {
  const ips = flux.lanAddresses();
  tray.setToolTip(ips.length ? `Flux - ${ips[0]}:${flux.port}` : 'Flux - no network');
  tray.setContextMenu(buildMenu());
}

async function showQr() {
  const ips = flux.lanAddresses();
  if (qrWindow && !qrWindow.isDestroyed()) qrWindow.close();

  const body = ips.length
    ? `<img src="${await QRCode.toDataURL(flux.pairingUri(), { margin: 2, width: 320 })}" width="320" height="320" alt="Pairing QR code">
       <p class="addr">${os.hostname()}<br>${ips.map((i) => `${i}:${flux.port}`).join('<br>')}</p>
       <p>Open Flux on your phone,<br>tap <b>SCAN QR TO PAIR</b>.</p>`
    : `<p class="warn">NO NETWORK</p><p>Connect this laptop to your phone hotspot<br>or WiFi, then open this again.</p>`;

  const html = `<!doctype html><meta charset="utf-8"><title>Flux</title>
    <style>
      body{margin:0;overflow:hidden;background:#000;color:#e5e5e5;font:13px Consolas,monospace;text-align:center;padding:24px}
      h1{letter-spacing:.3em;margin:0 0 4px;font-size:22px}h1 i{color:#d71921;font-style:normal}
      .tag{color:#8e8e8e;font-size:10px;letter-spacing:.15em;margin-bottom:18px}
      img{background:#fff;border-radius:12px}
      .addr{color:#8e8e8e;font-size:11px}.warn{color:#d71921;font-size:18px;margin-top:60px}
      p{line-height:1.6}
    </style>
    <h1>FLUX<i>.</i></h1><div class="tag">LOCAL SHARING. NO CLOUD.</div>${body}`;

  qrWindow = new BrowserWindow({
    width: 400,
    height: 560,
    resizable: false,
    autoHideMenuBar: true,
    title: 'Flux - pair your phone',
    backgroundColor: '#000000',
    icon: path.join(__dirname, 'build', 'icon.png'),
    webPreferences: { sandbox: true },
  });
  qrWindow.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`);
}

function notify(item) {
  if (!Notification.isSupported()) return;
  const preview = item.preview.replace(/\s+/g, ' ').slice(0, 100);
  const n = new Notification({
    title: item.type === 'image' ? 'Received from phone: image' : `Received from phone: ${item.type}`,
    body: item.type === 'image'
      ? `Saved to Downloads\\Flux\\${preview}. Click to open.`
      : `"${preview}"\nCopied. Ready to paste (Ctrl+V).`,
    silent: false,
  });
  if (item.file) n.on('click', () => shell.showItemInFolder(item.file));
  n.show();
}

// Must match build.appId so Windows shows Flux notifications under the Flux name.
app.setAppUserModelId('com.flux.receiver');

app.on('second-instance', () => showQr());
app.on('window-all-closed', () => {}); // keep running in the tray

app.whenReady().then(async () => {
  flux = createFlux({
    configDir,
    writeClipboard: (text) => clipboard.writeText(text),
    onItem: (item) => {
      history.unshift(item);
      if (history.length > HISTORY_MAX) history.pop();
      notify(item);
      refreshTray();
    },
  });

  try {
    await flux.start();
  } catch (e) {
    dialog.showErrorBox(
      'Flux',
      e.code === 'EADDRINUSE'
        ? `Port ${flux.port} is already in use. Close the terminal version of Flux (node server.js) and try again.`
        : e.message,
    );
    app.quit();
    return;
  }

  tray = new Tray(loadTrayIcon());
  tray.on('click', showQr);
  refreshTray();
  // Addresses change when the network does; keep the tooltip fresh.
  setInterval(refreshTray, 30000);

  if (!readSettings().seenQr) {
    writeSettings({ seenQr: true });
    // An installed copy should be there after every reboot; the user can untick it in the tray menu.
    if (app.isPackaged) {
      setOpenAtLogin(true);
      refreshTray();
    }
    showQr();
  }
});
