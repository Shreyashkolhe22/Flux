/* Hero tunnel: Flux cards fly toward the viewer as the page scrolls. A plain-JS take on the "perspective tunnel"
   idea: cards sit on a golden-angle spiral at different depths, scroll progress moves the camera through them
   (smoothed by a spring), the pointer tilts the whole scene, and the headline scales away as you go in. */
(function () {
  'use strict';

  var section = document.getElementById('tunnel');
  var world = document.getElementById('tunnelWorld');
  if (!section || !world) return;
  var copy = document.getElementById('tunnelCopy');
  var end = document.getElementById('tunnelEnd');
  var hint = document.getElementById('tunnelHint');
  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  var SPACING = 360;   // distance between cards along the tunnel
  var GOLDEN = 137.508 * Math.PI / 180;

  /* ---- what flies by ---- */
  var ITEMS = [
    { t: 'phone', img: 'assets/app-home.png' },
    { t: 'chip', k: 'Link', v: 'https://github.com/flux' },
    { t: 'toast' },
    { t: 'phone', img: 'assets/app-sent.png' },
    { t: 'chip', k: 'File', v: 'report-final.pdf', bar: true },
    { t: 'chip', k: 'Text', v: 'Meet at 6, room 204' },
    { t: 'phone', img: 'assets/app-settings.png' },
    { t: 'chip', k: 'Image', v: 'IMG_2041.jpg', bar: true },
    { t: 'toast' },
    { t: 'phone', img: 'assets/app-home-light.png' }
  ];

  function el(tag, cls, html) { var e = document.createElement(tag); if (cls) e.className = cls; if (html) e.innerHTML = html; return e; }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }

  var cards = ITEMS.map(function (it, i) {
    var c = el('div', 't-card');
    if (it.t === 'phone') c.innerHTML = '<div class="phone"><img src="' + it.img + '" alt="" width="540" height="1200" loading="lazy"></div>';
    else if (it.t === 'toast') c.innerHTML = '<div class="toast"><div class="toast-ico"><img src="assets/favicon.png" alt="" width="28" height="28"></div><div class="toast-body"><b>Received from phone</b><span>Copied. Ready to paste</span><span class="toast-sub">Press Ctrl+V</span></div></div>';
    else c.innerHTML = '<div class="t-chip"><small>' + esc(it.k) + '</small><b>' + esc(it.v) + '</b>' + (it.bar ? '<div class="bar"></div>' : '') + '</div>';
    world.appendChild(c);
    return { node: c, kind: it.t, i: i, x: 0, y: 0, z: 0, tilt: 0 };
  });

  /* ---- layout: golden-angle spiral, kept out of the middle where the headline sits ---- */
  var W = 0, H = 0, travel = 0, narrow = false;
  function layout() {
    var r = section.querySelector('.tunnel-stage').getBoundingClientRect();
    W = r.width; H = r.height;
    narrow = W < 700;
    var unit = Math.min(W, H);
    var phoneW = narrow ? 104 : Math.min(230, Math.max(130, unit * 0.26));
    var chipW = narrow ? 160 : 250;
    cards.forEach(function (c) {
      var a = c.i * GOLDEN;
      var rx = W * (narrow ? 0.36 : 0.44), ry = H * (narrow ? 0.34 : 0.36);
      var k = 0.92 + ((c.i * 37) % 10) / 40;          // slight spread so cards do not sit on one ring
      var cx = Math.cos(a) * rx * k, minX = W * (narrow ? 0.12 : 0.24);
      c.x = Math.abs(cx) < minX ? (cx < 0 ? -minX : minX) : cx;
      c.y = Math.sin(a) * ry * k;
      c.z = -c.i * SPACING;
      c.tilt = Math.cos(a) * (narrow ? 6 : 10);
      c.node.style.setProperty('--cw', (c.kind === 'phone' ? phoneW : chipW) + 'px');
      c.node.style.marginLeft = -(c.kind === 'phone' ? phoneW : chipW) / 2 + 'px';
      c.node.style.marginTop = (c.kind === 'phone' ? -phoneW * 1.2 : -34) + 'px';
    });
    travel = (ITEMS.length - 1) * SPACING + 1100;
    view.style.perspective = (narrow ? 900 : 1200) + 'px';
  }
  var view = world.parentNode;

  /* ---- draw one frame for progress p (0 to 1), pointer (-1..1) ---- */
  function render(p, mx, my) {
    var cam = p * travel;
    world.style.transform = 'rotateX(' + (-my * 3).toFixed(2) + 'deg) rotateY(' + (mx * 4).toFixed(2) + 'deg) translate3d(' + (-mx * 14).toFixed(1) + 'px,' + (-my * 10).toFixed(1) + 'px,0)';
    var maxOp = narrow ? 0.55 * (0.3 + 0.7 * Math.min(1, p / 0.2)) : 1;
    for (var n = 0; n < cards.length; n++) {
      var c = cards[n], z = c.z + cam;
      // fade in from the distance, fade out as the card passes the camera
      var op = Math.min(1, Math.max(0, (z + 2000) / 700)) * Math.min(1, Math.max(0, (700 - z) / 500)) * maxOp;
      c.node.style.opacity = op.toFixed(3);
      c.node.style.visibility = op < 0.01 ? 'hidden' : 'visible';
      c.node.style.transform = 'translate3d(' + c.x.toFixed(1) + 'px,' + c.y.toFixed(1) + 'px,' + z.toFixed(1) + 'px) rotateZ(' + c.tilt.toFixed(1) + 'deg)';
    }
    // headline: full size at the start, grows and fades as you enter, then the closing line arrives
    var t = Math.min(1, p / 0.28);
    copy.style.opacity = (1 - t).toFixed(3);
    copy.style.transform = 'scale(' + (1 + t * 0.35).toFixed(3) + ')';
    copy.style.pointerEvents = t > 0.5 ? 'none' : '';
    copy.style.visibility = t >= 1 ? 'hidden' : 'visible';
    var e = Math.min(1, Math.max(0, (p - 0.72) / 0.2));
    end.style.opacity = e.toFixed(3);
    end.style.transform = 'scale(' + (0.8 + e * 0.2).toFixed(3) + ')';
    hint.style.opacity = (1 - Math.min(1, p / 0.08)).toFixed(3);
  }

  layout();
  window.addEventListener('resize', function () { layout(); target = progress(); });

  if (reduced) {
    section.classList.add('tunnel-reduced');
    layout();
    render(0.14, 0, 0);
    copy.style.opacity = 1; copy.style.transform = 'none'; copy.style.visibility = 'visible'; copy.style.pointerEvents = '';
    return;
  }

  /* ---- scroll -> progress, eased with a spring-like follow ---- */
  function progress() {
    var r = section.getBoundingClientRect();
    var span = Math.max(1, r.height - window.innerHeight);
    return Math.min(1, Math.max(0, -r.top / span));
  }
  var target = progress(), cur = target, mx = 0, my = 0, tx = 0, ty = 0, raf = 0, onScreen = true;

  function frame() {
    raf = 0;
    cur += (target - cur) * 0.12;
    mx += (tx - mx) * 0.08; my += (ty - my) * 0.08;
    if (Math.abs(target - cur) < 0.0004) cur = target;
    render(cur, mx, my);
    if (cur !== target || Math.abs(tx - mx) > 0.003 || Math.abs(ty - my) > 0.003) raf = requestAnimationFrame(frame);
  }
  function kick() { if (!raf && onScreen) raf = requestAnimationFrame(frame); }

  window.addEventListener('scroll', function () { target = progress(); kick(); }, { passive: true });
  if (window.matchMedia('(hover: hover)').matches) {
    window.addEventListener('pointermove', function (e) {
      tx = (e.clientX / window.innerWidth - 0.5) * 2;
      ty = (e.clientY / window.innerHeight - 0.5) * 2;
      kick();
    }, { passive: true });
  }
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(function (es) { onScreen = es[0].isIntersecting; if (onScreen) { target = progress(); kick(); } }).observe(section);
  }
  render(cur, 0, 0);
})();
