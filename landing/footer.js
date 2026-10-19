/* Halftone wordmark footer: the word is set enormous, cropped by the bottom edge and printed as a field of
   halftone dots. Each dot is sized by how much of the letter covers its cell. The pointer parts the dots on
   springs (they warm in colour as they leave their place); a click sends a shock ring through the word.
   Plain-JS port of the "halftone-wordmark-footer" component, using the page's own colours. */
(function () {
  'use strict';

  var root = document.getElementById('footer');
  if (!root) return;
  var canvas = root.querySelector('canvas');
  var ctx = canvas && canvas.getContext('2d');
  if (!ctx) return;

  /* ---- settings ---- */
  var WORD = 'flux.';
  var WEIGHT = 800;
  var SANS = '"Inter", "Helvetica Neue", Arial, system-ui, sans-serif';
  var GAP = 7;        // distance between dot centres, CSS px
  var RADIUS = 80;    // how far the pointer pushes, CSS px
  var CROP = 0.2;     // how much of the cap height hangs below the bottom edge
  var GRAIN = 0.5;    // print grain, 0 to 1

  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---- pure helpers ---- */
  function hex(h) {
    var m = /^#?([0-9a-f]{3}|[0-9a-f]{6})$/i.exec((h || '').trim());
    if (!m) return null;
    var s = m[1].length === 3 ? m[1].replace(/./g, '$&$&') : m[1];
    return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
  }
  // area-true dot radius for a cell coverage in [0, 1]
  function dotRadius(cov, gap) { return Math.sqrt(Math.max(0, Math.min(1, cov))) * gap * 0.5; }
  // one step of a dot's spring back home, plus the push from a pointer within radius r
  function step(x, y, vx, vy, hx, hy, px, py, r) {
    var dx = x - px, dy = y - py, d2 = dx * dx + dy * dy;
    if (r > 0 && d2 < r * r) {
      var d = Math.sqrt(d2) + 0.001, f = (1 - d / r) * 2.6;
      vx += (dx / d) * f; vy += (dy / d) * f;
    }
    vx = (vx + (hx - x) * 0.05) * 0.84;
    vy = (vy + (hy - y) * 0.05) * 0.84;
    return [x + vx, y + vy, vx, vy];
  }
  function warmth(x, y, hx, hy, span) { return Math.min(1, Math.hypot(x - hx, y - hy) / span); }

  /* ---- colours from the page's CSS variables, so the theme switch just works ---- */
  var bg = '#000', ink = '#fff', inkRGB = [255, 255, 255], warmRGB = [215, 25, 33];
  function readColors() {
    var cs = getComputedStyle(document.documentElement);
    bg = cs.getPropertyValue('--bg').trim() || '#000';
    ink = cs.getPropertyValue('--text').trim() || '#fff';
    inkRGB = hex(ink) || [255, 255, 255];
    warmRGB = hex(cs.getPropertyValue('--red')) || [215, 25, 33];
    wake();
  }

  /* ---- state ---- */
  var w = 0, h = 0, dpr = 1, px = -1e5, py = -1e5, raf = 0, visible = true, awake = true;
  var ring = { x: 0, y: 0, t: -1 };
  var dots = new Float32Array(0), count = 0, grainTile = null; // dots: x, y, vx, vy, hx, hy, r per dot

  function layout() {
    var rect = root.getBoundingClientRect();
    w = Math.max(1, Math.round(rect.width));
    h = Math.max(1, Math.round(rect.height));
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);

    // Set the word once on a 1x mask, as big as fits the width and the space under the links.
    var mask = document.createElement('canvas');
    mask.width = w; mask.height = h;
    var m = mask.getContext('2d', { willReadFrequently: true });
    if (!m) return;
    m.font = WEIGHT + ' 100px ' + SANS;
    var probe = m.measureText(WORD);
    var w100 = probe.width || 1, a100 = probe.actualBoundingBoxAscent || 72;
    var rule = root.querySelector('.hwf-rule');
    var freeTop = rule ? rule.offsetTop + rule.offsetHeight + 16 : 180;
    var sizeByWidth = (w * 0.9 / w100) * 100;
    var sizeByHeight = ((h - freeTop) / ((1 - CROP) * (a100 / 100))) ;
    var size = Math.max(40, Math.min(sizeByWidth, sizeByHeight));
    m.font = WEIGHT + ' ' + size + 'px ' + SANS;
    var box = m.measureText(WORD);
    var cap = box.actualBoundingBoxAscent || size * 0.72;
    m.fillStyle = '#000';
    m.textBaseline = 'alphabetic';
    m.fillText(WORD, (w - box.width) / 2, h + cap * CROP);
    var img = m.getImageData(0, 0, w, h).data;

    var cols = Math.ceil(w / GAP), rows = Math.ceil(h / GAP), tmp = [];
    for (var gy = 0; gy < rows; gy++) {
      for (var gx = 0; gx < cols; gx++) {
        var sum = 0; // coverage: average alpha over a 3x3 sample of the cell
        for (var sy = 0; sy < 3; sy++) {
          for (var sx = 0; sx < 3; sx++) {
            var x = Math.min(w - 1, Math.floor(gx * GAP + ((sx + 0.5) * GAP) / 3));
            var y = Math.min(h - 1, Math.floor(gy * GAP + ((sy + 0.5) * GAP) / 3));
            sum += img[(y * w + x) * 4 + 3];
          }
        }
        var cov = sum / (9 * 255);
        if (cov < 0.06) continue;
        var hx = gx * GAP + GAP / 2, hy = gy * GAP + GAP / 2;
        tmp.push(hx, hy, 0, 0, hx, hy, dotRadius(cov, GAP));
      }
    }
    dots = new Float32Array(tmp);
    count = tmp.length / 7;

    if (!grainTile) { // a fixed tile of print grain, drawn once
      grainTile = document.createElement('canvas');
      grainTile.width = 256; grainTile.height = 256;
      var g = grainTile.getContext('2d');
      var id = g.createImageData(256, 256);
      for (var i = 0; i < id.data.length; i += 4) {
        var v = Math.random() * 255;
        id.data[i] = id.data[i + 1] = id.data[i + 2] = v;
        id.data[i + 3] = Math.random() < 0.5 ? 0 : 255;
      }
      g.putImageData(id, 0, 0);
    }
    awake = true;
  }

  function draw(now) {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, w, h);

    var r = reduced ? 0 : RADIUS;
    var ringAge = ring.t < 0 ? 1e9 : now - ring.t, ringR = ringAge * 0.9, moving = false;
    for (var i = 0; i < count; i++) {
      var j = i * 7, x = dots[j], y = dots[j + 1], vx = dots[j + 2], vy = dots[j + 3];
      var hx = dots[j + 4], hy = dots[j + 5];
      if (!reduced) {
        if (ringAge < 900) {
          var dx = hx - ring.x, dy = hy - ring.y, d = Math.sqrt(dx * dx + dy * dy) + 0.001;
          var band = 1 - Math.min(1, Math.abs(d - ringR) / 26);
          if (band > 0) {
            var f = band * 3.2 * (1 - ringAge / 900);
            vx += (dx / d) * f; vy += (dy / d) * f;
          }
        }
        var s = step(x, y, vx, vy, hx, hy, px, py, r);
        x = s[0]; y = s[1]; vx = s[2]; vy = s[3];
        if (Math.abs(vx) + Math.abs(vy) > 0.02 || Math.abs(x - hx) + Math.abs(y - hy) > 0.05) moving = true;
        else { x = hx; y = hy; vx = 0; vy = 0; }
        dots[j] = x; dots[j + 1] = y; dots[j + 2] = vx; dots[j + 3] = vy;
      }
      var k = warmth(x, y, hx, hy, 28);
      ctx.fillStyle = k > 0.02
        ? 'rgb(' + Math.round(inkRGB[0] + (warmRGB[0] - inkRGB[0]) * k) + ',' +
          Math.round(inkRGB[1] + (warmRGB[1] - inkRGB[1]) * k) + ',' +
          Math.round(inkRGB[2] + (warmRGB[2] - inkRGB[2]) * k) + ')'
        : ink;
      ctx.beginPath();
      ctx.arc(x, y, dots[j + 6], 0, 6.2832);
      ctx.fill();
    }

    if (grainTile && GRAIN > 0) {
      ctx.globalAlpha = Math.min(1, GRAIN) * 0.09;
      ctx.globalCompositeOperation = 'overlay';
      var pattern = ctx.createPattern(grainTile, 'repeat');
      if (pattern) { ctx.fillStyle = pattern; ctx.fillRect(0, 0, w, h); }
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = 'source-over';
    }
    awake = moving || ringAge < 900 || px > -1e4; // sleep once everything is home
  }

  function loop(now) {
    raf = 0;
    if (!visible) return;
    draw(now);
    if (awake) raf = requestAnimationFrame(loop);
  }
  function wake() {
    awake = true;
    if (!raf && visible) raf = requestAnimationFrame(loop);
  }

  /* ---- pointer ---- */
  function local(e) { var b = canvas.getBoundingClientRect(); return [e.clientX - b.left, e.clientY - b.top]; }
  root.addEventListener('pointermove', function (e) { var p = local(e); px = p[0]; py = p[1]; wake(); });
  root.addEventListener('pointerleave', function () { px = -1e5; py = -1e5; wake(); });
  root.addEventListener('pointerdown', function (e) {
    if (reduced || (e.target.closest && e.target.closest('a,button'))) return;
    var p = local(e);
    ring = { x: p[0], y: p[1], t: performance.now() };
    wake();
  });

  /* ---- back to top ---- */
  var up = root.querySelector('.hwf-up');
  if (up) up.addEventListener('click', function () { window.scrollTo({ top: 0, behavior: reduced ? 'auto' : 'smooth' }); });

  /* ---- lifecycle ---- */
  readColors();
  layout();
  draw(performance.now());
  wake();
  new ResizeObserver(function () { layout(); wake(); }).observe(root);
  new IntersectionObserver(function (es) { visible = es[0] ? es[0].isIntersecting : true; if (visible) wake(); }).observe(root);
  new MutationObserver(readColors).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
  var mq = window.matchMedia('(prefers-color-scheme: dark)');
  if (mq.addEventListener) mq.addEventListener('change', readColors);
  // a web font that lands late re-sets the word in its real face
  if (document.fonts && document.fonts.load) {
    document.fonts.load(WEIGHT + ' 100px Inter', WORD).then(function () { layout(); wake(); }, function () {});
  }
})();
