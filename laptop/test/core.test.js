'use strict';
// Run with: npm test
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const { createFlux, safeName } = require('../core');

const PORT = 38000 + Math.floor(Math.random() * 1000);
const MAX = 1000; // small cap so the size test is cheap
let flux, dir, saveDir, key;
const items = [];

before(async () => {
  dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flux-test-'));
  saveDir = path.join(dir, 'saved');
  flux = createFlux({
    configDir: dir,
    saveDir,
    port: PORT,
    maxFileBytes: MAX,
    writeClipboard: () => {},
    onItem: (i) => items.push(i),
    log: () => {},
  });
  key = flux.key;
  await flux.start();
});

after(() => {
  flux.stop();
  fs.rmSync(dir, { recursive: true, force: true });
});

beforeEach(() => {
  fs.rmSync(saveDir, { recursive: true, force: true });
  items.length = 0;
});

let n = 0;
const upload = (name, body, extra = {}) =>
  fetch(`http://127.0.0.1:${PORT}/file`, {
    method: 'POST',
    headers: {
      'X-Key': key,
      'X-Id': `id-${++n}-${Math.random()}`,
      'X-Name': encodeURIComponent(name),
      ...extra,
    },
    body,
  });

const saved = () => (fs.existsSync(saveDir) ? fs.readdirSync(saveDir).sort() : []);

test('saves a file with its content and reports it', async () => {
  const res = await upload('notes.txt', Buffer.from('hello flux'));
  assert.equal(res.status, 200);
  assert.deepEqual(saved(), ['notes.txt']);
  assert.equal(fs.readFileSync(path.join(saveDir, 'notes.txt'), 'utf8'), 'hello flux');
  assert.equal(items.length, 1);
  assert.equal(items[0].type, 'file');
  assert.equal(items[0].preview, 'notes.txt');
});

test('keeps non-ASCII names', async () => {
  const res = await upload('रिपोर्ट é.txt', Buffer.from('x'));
  assert.equal(res.status, 200);
  assert.deepEqual(saved(), ['रिपोर्ट é.txt']);
});

test('rejects a wrong key and saves nothing', async () => {
  const res = await upload('a.txt', Buffer.from('x'), { 'X-Key': 'nope' });
  assert.equal(res.status, 401);
  assert.deepEqual(saved(), []);
});

test('rejects a file over the size cap and saves nothing', async () => {
  const res = await upload('big.bin', Buffer.alloc(MAX + 1));
  assert.equal(res.status, 413);
  assert.deepEqual(saved(), []);
});

test('accepts a file exactly at the cap', async () => {
  const res = await upload('edge.bin', Buffer.alloc(MAX, 1));
  assert.equal(res.status, 200);
  assert.equal(fs.statSync(path.join(saveDir, 'edge.bin')).size, MAX);
});

test('a resent id is not saved twice', async () => {
  const headers = { 'X-Id': 'same-id' };
  const a = await upload('once.txt', Buffer.from('1'), headers);
  const b = await upload('once.txt', Buffer.from('1'), headers);
  assert.equal(a.status, 200);
  assert.equal((await b.json()).duplicate, true);
  assert.deepEqual(saved(), ['once.txt']);
});

test('never overwrites: same name gets (1), (2)', async () => {
  for (let i = 0; i < 3; i++) await upload('report.pdf', Buffer.from(`v${i}`));
  assert.deepEqual(saved(), ['report (1).pdf', 'report (2).pdf', 'report.pdf']);
  assert.equal(fs.readFileSync(path.join(saveDir, 'report.pdf'), 'utf8'), 'v0');
});

test('path traversal in the name stays inside the save folder', async () => {
  const res = await upload('..\\..\\evil.txt', Buffer.from('x'));
  assert.equal(res.status, 200);
  assert.deepEqual(saved(), ['evil.txt']);
  assert.equal(fs.existsSync(path.join(dir, 'evil.txt')), false);
});

test('rejects a body with no Content-Length', async () => {
  const res = await new Promise((resolve) => {
    const req = http.request(
      { host: '127.0.0.1', port: PORT, path: '/file', method: 'POST',
        headers: { 'X-Key': key, 'X-Id': 'chunked', 'X-Name': 'c.txt', 'Transfer-Encoding': 'chunked' } },
      (r) => { r.resume(); resolve(r.statusCode); },
    );
    req.write('abc');
    req.end();
  });
  assert.equal(res, 400);
  assert.deepEqual(saved(), []);
});

test('an upload cut off halfway leaves no partial file', async () => {
  await new Promise((resolve) => {
    const req = http.request({
      host: '127.0.0.1', port: PORT, path: '/file', method: 'POST',
      headers: { 'X-Key': key, 'X-Id': 'cut', 'X-Name': 'cut.bin', 'Content-Length': '900' },
    });
    req.on('error', () => {});
    req.write(Buffer.alloc(100));
    setTimeout(() => { req.destroy(); resolve(); }, 150);
  });
  await new Promise((r) => setTimeout(r, 300));
  assert.deepEqual(saved(), []);
  assert.equal(items.length, 0);
});

test('safeName handles hostile and awkward names', () => {
  assert.equal(safeName('a/b/c.txt'), 'c.txt');
  assert.equal(safeName('..\\..\\x.exe'), 'x.exe');
  assert.equal(safeName('con.txt'), '_con.txt');
  assert.equal(safeName('NUL'), '_NUL');
  assert.equal(safeName('bad<>:"|?*name.txt'), 'bad_______name.txt');
  assert.equal(safeName('trailing. . '), 'trailing');
  assert.equal(safeName(''), 'file');
  assert.equal(safeName('...'), 'file');
  const long = safeName('x'.repeat(300) + '.pdf');
  assert.ok(long.length <= 120 && long.endsWith('.pdf'));
});
