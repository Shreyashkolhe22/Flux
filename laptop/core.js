'use strict';
// Flux receiver core. Shared by the terminal script (server.js) and the tray app (main.js).
const express = require('express');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_FILE_BYTES = 100 * 1024 * 1024;
const IMAGE_TYPES = {
  'image/jpeg': { ext: 'jpg', magic: [0xff, 0xd8, 0xff] },
  'image/png': { ext: 'png', magic: [0x89, 0x50, 0x4e, 0x47] },
  'image/webp': { ext: 'webp', magic: [0x52, 0x49, 0x46, 0x46] },
};

// LAN IPv4 addresses, private ranges only, virtual adapters skipped.
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

// Makes a received filename safe to write on Windows: no path parts, no reserved
// characters or device names, bounded length. Always returns a usable name.
function safeName(raw) {
  let name = String(raw || '').replace(/[\\/]+/g, '/').split('/').pop();
  name = name.replace(/[\x00-\x1f<>:"|?*]/g, '_').replace(/^[ .]+|[ .]+$/g, '');
  if (/^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$/i.test(name)) name = '_' + name;
  if (name.length > 120) {
    const ext = path.extname(name).slice(0, 20);
    name = name.slice(0, 120 - ext.length) + ext;
  }
  return name || 'file';
}

// name.ext -> name (1).ext -> name (2).ext ... so nothing is ever overwritten.
function uniquePath(dir, name) {
  const ext = path.extname(name);
  const base = name.slice(0, name.length - ext.length);
  let candidate = path.join(dir, name);
  for (let i = 1; fs.existsSync(candidate) || fs.existsSync(candidate + '.part'); i++) {
    candidate = path.join(dir, `${base} (${i})${ext}`);
  }
  return candidate;
}

function keyOk(provided, expected) {
  const a = Buffer.from(String(provided || ''));
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/**
 * @param {object} opts
 * @param {string} opts.configDir  where config.json (the secret key) lives
 * @param {(text: string) => void} opts.writeClipboard
 * @param {(item: {type: string, preview: string, file?: string}) => void} [opts.onItem]
 * @param {(msg: string) => void} [opts.log]
 * @param {number} [opts.port]
 * @param {string} [opts.saveDir]
 */
function createFlux(opts) {
  const port = opts.port || Number(process.env.FLUX_PORT) || 3000;
  const saveDir = opts.saveDir || path.join(os.homedir(), 'Downloads', 'Flux');
  const maxFileBytes = opts.maxFileBytes || MAX_FILE_BYTES;
  const configPath = path.join(opts.configDir, 'config.json');
  const log = opts.log || ((m) => console.log(`[${new Date().toLocaleTimeString()}] ${m}`));

  function resetKey() {
    const cfg = { key: crypto.randomBytes(24).toString('hex') };
    fs.mkdirSync(opts.configDir, { recursive: true });
    fs.writeFileSync(configPath, JSON.stringify(cfg, null, 2));
    return cfg;
  }

  function loadConfig() {
    try {
      const cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      if (typeof cfg.key === 'string' && cfg.key.length >= 32) return cfg;
    } catch (_) {}
    return resetKey();
  }

  let config = loadConfig();
  let server = null;

  function pairingUri() {
    const ips = lanAddresses();
    return `flux://pair?ips=${ips.join(',')}&port=${port}&key=${config.key}&name=${encodeURIComponent(os.hostname())}`;
  }

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
      let item;
      if (type === 'image') {
        const spec = IMAGE_TYPES[mime];
        if (!spec) return res.status(400).json({ error: 'unsupported image type' });
        const buf = Buffer.from(data, 'base64');
        if (buf.length > MAX_IMAGE_BYTES) return res.status(413).json({ error: 'image too large' });
        if (!spec.magic.every((b, i) => buf[i] === b)) {
          return res.status(400).json({ error: 'not a valid image' });
        }
        fs.mkdirSync(saveDir, { recursive: true });
        const d = new Date();
        const p = (n) => String(n).padStart(2, '0');
        const stamp = `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
        const file = path.join(saveDir, `${stamp}-${id.replace(/[^a-z0-9]/gi, '').slice(0, 4)}.${spec.ext}`);
        fs.writeFileSync(file, buf);
        item = { type, preview: path.basename(file), file };
        log(`OK from ${src}: image saved -> ${file}`);
      } else {
        opts.writeClipboard(data);
        item = { type, preview: data.length > 80 ? `${data.slice(0, 80)}...` : data, full: data };
        log(`OK from ${src}: ${type} copied (${data.length} chars)`);
      }
      seen.add(id);
      seenOrder.push(id);
      if (seenOrder.length > 100) seen.delete(seenOrder.shift());
      if (opts.onItem) opts.onItem({ ...item, at: Date.now() });
      res.json({ ok: true });
    } catch (e) {
      log(`ERROR: ${e.message}`);
      res.status(500).json({ error: 'failed to handle item' });
    }
  });

  // Files are streamed straight to disk (raw body), so large files do not sit in memory.
  // Headers: X-Key, X-Id, X-Name (URL-encoded filename), Content-Length.
  app.post('/file', (req, res) => {
    const src = req.socket.remoteAddress;
    const reject = (status, error) => {
      if (!res.headersSent) res.status(status).set('Connection', 'close').json({ error });
      req.resume();
    };
    if (!keyOk(req.get('X-Key'), config.key)) {
      log(`REJECTED (bad key) from ${src}`);
      return reject(401, 'bad key');
    }
    const id = String(req.get('X-Id') || '');
    const length = Number(req.get('Content-Length'));
    if (!id || id.length > 100 || !Number.isInteger(length) || length <= 0) {
      return reject(400, 'bad payload');
    }
    if (length > maxFileBytes) return reject(413, 'file too large');
    if (seen.has(id)) {
      req.resume();
      return res.json({ ok: true, duplicate: true });
    }

    let decoded = '';
    try { decoded = decodeURIComponent(String(req.get('X-Name') || '')); } catch (_) {}
    const name = safeName(decoded);

    let finalPath, partPath, out;
    try {
      fs.mkdirSync(saveDir, { recursive: true });
      finalPath = uniquePath(saveDir, name);
      partPath = finalPath + '.part';
      out = fs.createWriteStream(partPath);
    } catch (e) {
      log(`ERROR: ${e.message}`);
      return reject(500, 'failed to handle item');
    }

    let received = 0;
    let done = false;
    const cleanup = () => {
      done = true;
      out.destroy();
      fs.unlink(partPath, () => {});
    };

    req.on('data', (chunk) => {
      received += chunk.length;
      if (!done && received > maxFileBytes) {
        cleanup();
        reject(413, 'file too large');
      }
    });
    req.pipe(out);
    // Client went away mid-upload: drop the partial file.
    res.on('close', () => { if (!done && !res.writableFinished) cleanup(); });
    out.on('error', (e) => {
      if (done) return;
      log(`ERROR: ${e.message}`);
      cleanup();
      reject(500, 'failed to handle item');
    });
    out.on('finish', () => {
      if (done) return;
      if (received !== length) {
        cleanup();
        return reject(400, 'incomplete upload');
      }
      try {
        fs.renameSync(partPath, finalPath);
      } catch (e) {
        log(`ERROR: ${e.message}`);
        cleanup();
        return reject(500, 'failed to handle item');
      }
      done = true;
      seen.add(id);
      seenOrder.push(id);
      if (seenOrder.length > 100) seen.delete(seenOrder.shift());
      log(`OK from ${src}: file saved -> ${finalPath} (${received} bytes)`);
      if (opts.onItem) {
        opts.onItem({ type: 'file', preview: path.basename(finalPath), file: finalPath, at: Date.now() });
      }
      res.json({ ok: true });
    });
  });

  // Payload too large / malformed JSON.
  app.use((err, _req, res, _next) => {
    if (err.type === 'entity.too.large') return res.status(413).json({ error: 'too large' });
    if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'bad json' });
    log(`ERROR: ${err.message}`);
    res.status(500).json({ error: 'server error' });
  });

  return {
    port,
    saveDir,
    lanAddresses,
    pairingUri,
    get key() { return config.key; },
    resetKey() { config = resetKey(); },
    start() {
      return new Promise((resolve, reject) => {
        server = app.listen(port, '0.0.0.0', () => resolve());
        server.once('error', reject);
      });
    },
    stop() {
      if (server) server.close();
    },
  };
}

module.exports = { createFlux, lanAddresses, safeName };
