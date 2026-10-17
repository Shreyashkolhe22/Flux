'use strict';
// Terminal mode: `node server.js` (use `--reset` to generate a new key).
// For the tray app, run `npm run tray` instead.
const clipboardy = require('clipboardy');
const qrcode = require('qrcode-terminal');
const os = require('os');
const { createFlux } = require('./core');

const flux = createFlux({
  configDir: __dirname,
  writeClipboard: (text) => clipboardy.writeSync(text),
});

if (process.argv.includes('--reset')) {
  flux.resetKey();
  console.log('New key generated. Re-pair your phone.');
}

flux
  .start()
  .then(() => {
    const ips = flux.lanAddresses();
    console.log('\n=== FLUX ===');
    if (ips.length === 0) {
      console.log('No LAN address found. Connect to your phone hotspot or WiFi first.');
    } else {
      console.log(`Laptop: ${os.hostname()}   Address: ${ips.map((i) => `${i}:${flux.port}`).join(', ')}`);
      console.log('Scan this in the Flux app (Not connected -> Scan QR to pair):\n');
      qrcode.generate(flux.pairingUri(), { small: true });
    }
    console.log(`[${new Date().toLocaleTimeString()}] Listening on port ${flux.port}. Waiting for items...`);
  })
  .catch((e) => {
    console.error(e.code === 'EADDRINUSE'
      ? `Port ${flux.port} is already in use. Is Flux already running (check the tray)?`
      : e.message);
    process.exit(1);
  });
