'use strict';
// Flux laptop receiver. Local network only, no cloud.
const express = require('express');
const clipboardy = require('clipboardy');
const qrcode = require('qrcode-terminal');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PORT = Number(process.env.FLUX_PORT) || 3000;
const CONFIG_PATH = path.join(__dirname, 'config.json');
const SAVE_DIR = path.join(os.homedir(), 'Downloads', 'Flux');
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const IMAGE_TYPES = {
  'image/jpeg': { ext: 'jpg', magic: [0xff, 0xd8, 0xff] },
  'image/png': { ext: 'png', magic: [0x89, 0x50, 0x4e, 0x47] },
  'image/webp': { ext: 'webp', magic: [0x52, 0x49, 0x46, 0x46] },
};

function loadConfig() {
  try {
    const cfg = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    if (typeof cfg.key === 'string' && cfg.key.length >= 32) return cfg;
  } catch (_) {}
  return resetKey();
}

function resetKey() {
  const cfg = { key: crypto.randomBytes(24).toString('hex') };
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 2));
  return cfg;
}

// LAN IPv4 addresses, private ranges first, virtual adapters skipped.
function lanAddresses() {
  const skip = /vethernet|virtualbox|vmware|loopback|wsl|docker|vpn|tailscale|zerotier/i;
  const out = [];
  for (const [name, list] of Object.entries(os.networkInterfaces())) {
    if (skip.test(name)) continue;
    for (const a of list || []) {
      if (a.family !== 'IPv4' || a.internal) continue;
      if (/^(192\.168\.|10\.|172\.(1[6-9]|2\d|3[01])\.)/.test(a.address)) out.push(a.address);
    }
  }
  return out;
}

function log(msg) {
  console.log(`[${new Date().toLocaleTimeString()}] ${msg}`);
}

function keyOk(provided, expected) {
  const a = Buffer.from(String(provided || ''));
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function pairingUri(ips, key) {
  return `flux://pair?ips=${ips.join(',')}&port=${PORT}&key=${key}&name=${encodeURIComponent(os.hostname())}`;
}

function printPairing(config) {
  const ips = lanAddresses();
  console.log('\n=== FLUX ===');
  if (ips.length === 0) {
    console.log('No LAN address found. Connect to your phone hotspot or WiFi first.');
    return;
  }
  console.log(`Laptop: ${os.hostname()}   Address: ${ips.map((i) => `${i}:${PORT}`).join(', ')}`);
  console.log('Scan this in the Flux app (Not connected -> Scan QR to pair):\n');
  qrcode.generate(pairingUri(ips, config.key), { small: true });
}

function createApp(config) {
  const app = express();
  const seen = new Set();
  const seenOrder = [];

  app.disable('x-powered-by');
  app.use(express.json({ limit: '8mb' }));

  // Unauthenticated, reveals nothing secret. Lets the phone confirm "is this Flux?"
  app.get('/ping', (_req, res) => res.json({ app: 'flux', name: os.hostname() }));

  app.post('/send', (req, res) => {
    const src = req.socket.remoteAddress;
    if (!keyOk(req.get('X-Key'), config.key)) {
      log(`REJECTED (bad key) from ${src}`);
      return res.status(401).json({ error: 'bad key' });
    }

    const { id, type, data, mime } = req.body || {};
    if (typeof id !== 'string' || !id || typeof data !== 'string' || !data ||
        !['text', 'link', 'image'].includes(type)) {
      return res.status(400).json({ error: 'bad payload' });
    }
    if (seen.has(id)) return res.json({ ok: true, duplicate: true });

    try {
      let detail;
      if (type === 'image') {
        const spec = IMAGE_TYPES[mime];
        if (!spec) return res.status(400).json({ error: 'unsupported image type' });
        const buf = Buffer.from(data, 'base64');
        if (buf.length > MAX_IMAGE_BYTES) return res.status(413).json({ error: 'image too large' });
        if (!spec.magic.every((b, i) => buf[i] === b)) {
          return res.status(400).json({ error: 'not a valid image' });
        }
        fs.mkdirSync(SAVE_DIR, { recursive: true });
        const d = new Date();
        const p = (n) => String(n).padStart(2, '0');
        const stamp = `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
        const file = path.join(SAVE_DIR, `${stamp}-${id.replace(/[^a-z0-9]/gi, '').slice(0, 4)}.${spec.ext}`);
        fs.writeFileSync(file, buf);
        detail = `image saved -> ${file}`;
      } else {
        clipboardy.writeSync(data);
        detail = `${type} copied (${data.length} chars)`;
      }
      seen.add(id);
      seenOrder.push(id);
      if (seenOrder.length > 100) seen.delete(seenOrder.shift());
      log(`OK from ${src}: ${detail}`);
      res.json({ ok: true });
    } catch (e) {
      log(`ERROR: ${e.message}`);
      res.status(500).json({ error: 'failed to handle item' });
    }
  });

  // Payload too large / malformed JSON.
  app.use((err, _req, res, _next) => {
    if (err.type === 'entity.too.large') return res.status(413).json({ error: 'too large' });
    if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'bad json' });
    log(`ERROR: ${err.message}`);
    res.status(500).json({ error: 'server error' });
  });

  return app;
}

function main() {
  if (process.argv.includes('--reset')) {
    resetKey();
    console.log('New key generated. Re-pair your phone.');
  }
  const config = loadConfig();
  const app = createApp(config);
  app.listen(PORT, '0.0.0.0', () => {
    printPairing(config);
    log(`Listening on port ${PORT}. Waiting for items...`);
  });
}

main();
