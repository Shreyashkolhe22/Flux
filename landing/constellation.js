/* Constellation grid background: a mesh of nodes that connect to their neighbours and
   are pushed away (with a shockwave that scales with cursor speed) by the pointer.
   Plain-JS port of the "constellation-grid" canvas component, drawn behind the whole page. */
(function () {
  'use strict';

  var canvas = document.getElementById('constellation');
  if (!canvas) return;
  var ctx = canvas.getContext('2d', { alpha: false });
  if (!ctx) return;

  var root = document.documentElement;
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Which colour highlights the nodes near the cursor. Uses the page's red;
  // change to '56, 189, 248' for the original sky-cyan accent.
  var ACCENT_OVERRIDE = null;

  var width = 0, height = 0, nodes = [], pairs = [], spacing = 55, connDist = 75;
  var palette = { bg: '#000', node: '255, 255, 255', accent: '215, 25, 33', dark: true };
  var mouse = { x: -1000, y: -1000, prevX: -1000, prevY: -1000, vx: 0, vy: 0, radius: 220 };

  /* ---------- colours, taken from the page's CSS variables so the theme switch just works ---------- */
  function toRgb(value, fallback) {
    var v = (value || '').trim();
    var m = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(v);
    if (!m) return fallback;
    var h = m[1].length === 3 ? m[1].replace(/./g, '$&$&') : m[1];
    return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
  }
  function readPalette() {
    var cs = getComputedStyle(root);
    var bg = toRgb(cs.getPropertyValue('--bg'), [0, 0, 0]);
    var text = toRgb(cs.getPropertyValue('--text'), [255, 255, 255]);
    var red = toRgb(cs.getPropertyValue('--red'), [215, 25, 33]);
    palette = {
      bg: 'rgb(' + bg.join(',') + ')',
      node: text.join(', '),
      accent: ACCENT_OVERRIDE || red.join(', '),
      dark: (bg[0] + bg[1] + bg[2]) / 3 < 128
    };
    if (reduceMotion) draw(0, true);
  }
  new MutationObserver(readPalette).observe(root, { attributes: true, attributeFilter: ['data-theme'] });
  var mq = window.matchMedia('(prefers-color-scheme: dark)');
  if (mq.addEventListener) mq.addEventListener('change', readPalette);

  /* ---------- nodes ---------- */
  function build() {
    var rect = canvas.getBoundingClientRect();
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = Math.max(1, Math.round(rect.width));
    height = Math.max(1, Math.round(rect.height));
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    spacing = width < 640 ? 50 : 55;
    // keep the node count sensible on very large screens
    while ((width / spacing) * (height / spacing) > 1500) spacing += 8;
    connDist = spacing * 1.36;

    var cols = Math.ceil(width / spacing) + 1, rows = Math.ceil(height / spacing) + 1;
    nodes = [];
    for (var i = 0; i < cols; i++) {
      for (var j = 0; j < rows; j++) {
        nodes.push({
          x: i * spacing, y: j * spacing, vx: 0, vy: 0, baseX: i * spacing, baseY: j * spacing,
          radius: Math.random() * 1.2 + 1.2,
          label: (i * 7).toString(16).toUpperCase() + ':' + (j * 11).toString(16).toUpperCase(),
          pulse: Math.random() * Math.PI * 2
        });
      }
    }
    // Only compare each node with the ones around its home cell, instead of every pair.
    pairs = [];
    for (var a = 0; a < cols; a++) {
      for (var b = 0; b < rows; b++) {
        for (var da = 0; da <= 2; da++) {
          for (var db = -2; db <= 2; db++) {
            if (da === 0 && db <= 0) continue;
            var c = a + da, d = b + db;
            if (c < cols && d >= 0 && d < rows) pairs.push(a * rows + b, c * rows + d);
          }
        }
      }
    }
    draw(0, true);
  }

  /* ---------- pointer ---------- */
  window.addEventListener('pointermove', function (e) { mouse.x = e.clientX; mouse.y = e.clientY; }, { passive: true });
  function leave() { mouse.x = -1000; mouse.y = -1000; }
  root.addEventListener('mouseleave', leave);
  window.addEventListener('pointerup', function (e) { if (e.pointerType !== 'mouse') leave(); });
  window.addEventListener('blur', leave);

  /* ---------- drawing ---------- */
  var SPRING_K = 18, DAMPING = 0.82;

  function draw(dt, still) {
    ctx.fillStyle = palette.bg;
    ctx.fillRect(0, 0, width, height);

    var speed = 0;
    if (!still) {
      mouse.vx = (mouse.x - mouse.prevX) / (dt * 1000 || 1);
      mouse.vy = (mouse.y - mouse.prevY) / (dt * 1000 || 1);
      mouse.prevX = mouse.x; mouse.prevY = mouse.y;
      speed = Math.sqrt(mouse.vx * mouse.vx + mouse.vy * mouse.vy);

      // spring-mass-damper physics: the cursor repels, the home position pulls back
      for (var i = 0; i < nodes.length; i++) {
        var n = nodes[i];
        n.pulse += dt * 3;
        var dx = mouse.x - n.x, dy = mouse.y - n.y;
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < mouse.radius && dist > 0) {
          var force = (1 - dist / mouse.radius) * (1500 + speed * 150);
          var angle = Math.atan2(dy, dx);
          n.vx -= Math.cos(angle) * force * dt;
          n.vy -= Math.sin(angle) * force * dt;
        }
        n.vx += (n.baseX - n.x) * SPRING_K * dt;
        n.vy += (n.baseY - n.y) * SPRING_K * dt;
        n.vx *= DAMPING; n.vy *= DAMPING;
        n.x += n.vx * dt * 60;
        n.y += n.vy * dt * 60;
      }
    }

    // connections
    var maxSq = connDist * connDist, lineBoost = palette.dark ? 0.18 : 0.08;
    ctx.lineWidth = 0.7;
    for (var p = 0; p < pairs.length; p += 2) {
      var A = nodes[pairs[p]], B = nodes[pairs[p + 1]];
      var ndx = A.x - B.x, ndy = A.y - B.y, dsq = ndx * ndx + ndy * ndy;
      if (dsq < maxSq) {
        ctx.strokeStyle = 'rgba(' + palette.node + ', ' + ((1 - Math.sqrt(dsq) / connDist) * lineBoost).toFixed(3) + ')';
        ctx.beginPath(); ctx.moveTo(A.x, A.y); ctx.lineTo(B.x, B.y); ctx.stroke();
      }
    }

    // nodes, highlights, radar rings and coordinate read-outs near the cursor
    ctx.font = '8px ui-monospace, SFMono-Regular, Consolas, monospace';
    for (var k = 0; k < nodes.length; k++) {
      var m = nodes[k];
      var mx = mouse.x - m.x, my = mouse.y - m.y, md = Math.sqrt(mx * mx + my * my);
      var near = md < mouse.radius;
      var alpha = near ? 0.95 : 0.25 + Math.sin(m.pulse) * 0.1;
      ctx.fillStyle = 'rgba(' + (near ? palette.accent : palette.node) + ', ' + alpha.toFixed(3) + ')';
      var r = near ? m.radius * 2.2 : m.radius + Math.sin(m.pulse) * 0.3;
      ctx.beginPath(); ctx.arc(m.x, m.y, Math.max(0.5, r), 0, Math.PI * 2); ctx.fill();

      if (md < 90) {
        var ring = ((m.pulse * 20) % 30) + 4;
        ctx.strokeStyle = 'rgba(' + palette.accent + ', ' + ((1 - ring / 34) * 0.4).toFixed(3) + ')';
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(m.x, m.y, ring, 0, Math.PI * 2); ctx.stroke();
        ctx.fillStyle = 'rgba(' + palette.accent + ', 0.85)';
        ctx.fillText(m.label, m.x + 10, m.y - 10);
        ctx.lineWidth = 0.7;
      }
    }
  }

  /* ---------- loop ---------- */
  var raf = 0, last = 0;
  function frame(now) {
    var dt = Math.min((now - last) / 1000, 0.05);
    last = now;
    draw(dt, false);
    raf = requestAnimationFrame(frame);
  }
  function start() { if (!raf && !reduceMotion) { last = performance.now(); raf = requestAnimationFrame(frame); } }
  function stop() { if (raf) { cancelAnimationFrame(raf); raf = 0; } }
  document.addEventListener('visibilitychange', function () { if (document.hidden) stop(); else start(); });

  var resizeTimer = 0;
  window.addEventListener('resize', function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () {
      var rect = canvas.getBoundingClientRect();
      // Phone browsers resize the viewport a little while scrolling; only rebuild for real changes.
      if (Math.abs(rect.width - width) > 1 || Math.abs(rect.height - height) > 160) build();
    }, 120);
  });

  readPalette();
  build();
  start();
})();
