/* Flux landing page: dot-matrix lettering, the copy / send / paste scene, sticky phone, theme, live download links. */
(function () {
  'use strict';

  var REPO = 'Shreyashkolhe22/Flux';
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var root = document.documentElement;
  var staticMode = location.search.indexOf('reveal=off') > -1; // ?reveal=off: everything visible, for screenshots
  if (staticMode) root.classList.add('static');

  /* ---------- dot-matrix glyphs (5 x 7), the same face the app draws ---------- */
  var G = {
    A: '01110 10001 10001 11111 10001 10001 10001', B: '11110 10001 10001 11110 10001 10001 11110',
    C: '01110 10001 10000 10000 10000 10001 01110', D: '11110 10001 10001 10001 10001 10001 11110',
    E: '11111 10000 10000 11110 10000 10000 11111', F: '11111 10000 10000 11110 10000 10000 10000',
    G: '01110 10001 10000 10111 10001 10001 01111', H: '10001 10001 10001 11111 10001 10001 10001',
    I: '01110 00100 00100 00100 00100 00100 01110', J: '00111 00010 00010 00010 00010 10010 01100',
    K: '10001 10010 10100 11000 10100 10010 10001', L: '10000 10000 10000 10000 10000 10000 11111',
    M: '10001 11011 10101 10101 10001 10001 10001', N: '10001 11001 10101 10011 10001 10001 10001',
    O: '01110 10001 10001 10001 10001 10001 01110', P: '11110 10001 10001 11110 10000 10000 10000',
    Q: '01110 10001 10001 10001 10101 10010 01101', R: '11110 10001 10001 11110 10100 10010 10001',
    S: '01111 10000 10000 01110 00001 00001 11110', T: '11111 00100 00100 00100 00100 00100 00100',
    U: '10001 10001 10001 10001 10001 10001 01110', V: '10001 10001 10001 10001 10001 01010 00100',
    W: '10001 10001 10001 10101 10101 11011 10001', X: '10001 10001 01010 00100 01010 10001 10001',
    Y: '10001 10001 01010 00100 00100 00100 00100', Z: '11111 00001 00010 00100 01000 10000 11111',
    '.': '0 0 0 0 0 0 1', ' ': '00 00 00 00 00 00 00'
  };
  var NS = 'http://www.w3.org/2000/svg';

  function drawDots(el) {
    var text = (el.getAttribute('data-text') || '').toUpperCase();
    var big = el.classList.contains('dots-hero') || el.classList.contains('dots-foot');
    var thin = el.hasAttribute('data-thin');
    var animate = el.classList.contains('dots-hero') && !reduceMotion;
    var circles = [], x = 0, index = 0;
    var svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('aria-hidden', 'true');
    for (var i = 0; i < text.length; i++) {
      var rows = (G[text[i]] || '').split(' ');
      if (!rows[0]) continue;
      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < rows[r].length; c++) {
          if (rows[r][c] !== '1') continue;
          var stop = text[i] === '.';
          var radius = stop ? 0.5 : (big ? 0.3 : (thin ? 0.3 : 0.4));
          var dot = document.createElementNS(NS, 'circle');
          dot.setAttribute('cx', x + c + 0.5);
          dot.setAttribute('cy', r + 0.5);
          dot.setAttribute('r', radius);
          dot.setAttribute('class', stop ? 'r' : 'd');
          if (animate) {
            dot.style.opacity = '0';
            dot.style.animation = 'dotin .5s ' + (index * 9) + 'ms both';
          }
          svg.appendChild(dot);
          circles.push({ node: dot, cx: x + c + 0.5, cy: r + 0.5, r: radius });
          index++;
        }
      }
      x += rows[0].length + 1;
    }
    svg.setAttribute('viewBox', '0 0 ' + (x - 1) + ' 7');
    el.textContent = '';
    el.appendChild(svg);
    el._dots = circles;
    el._svg = svg;
  }
  document.querySelectorAll('.dots').forEach(drawDots);

  /* Hero lettering: dots swell near the pointer. */
  var hero = document.querySelector('.dots-hero');
  if (hero && !reduceMotion && window.matchMedia('(hover: hover)').matches) {
    var pending = null, raf = 0;
    window.addEventListener('pointermove', function (e) {
      pending = e;
      if (raf) return;
      raf = requestAnimationFrame(function () {
        raf = 0;
        var box = hero.getBoundingClientRect();
        if (!pending || box.width === 0) return;
        var scale = box.width / (hero._svg.viewBox.baseVal.width || 1);
        var px = (pending.clientX - box.left) / scale, py = (pending.clientY - box.top) / scale;
        for (var i = 0; i < hero._dots.length; i++) {
          var d = hero._dots[i];
          var dist = Math.hypot(d.cx - px, d.cy - py);
          var k = dist < 3.6 ? 1 + (1 - dist / 3.6) * 1.1 : 1;
          d.node.setAttribute('r', (d.r * k).toFixed(3));
        }
      });
    }, { passive: true });
  }

  /* ---------- theme: auto / light / dark ---------- */
  var themeBtn = document.getElementById('theme');
  var order = ['system', 'light', 'dark'];
  var names = { system: 'AUTO', light: 'LIGHT', dark: 'DARK' };
  function choice() { return root.dataset.theme === 'light' || root.dataset.theme === 'dark' ? root.dataset.theme : 'system'; }
  function paintTheme() { if (themeBtn) themeBtn.textContent = names[choice()]; }
  if (themeBtn) {
    themeBtn.addEventListener('click', function () {
      var next = order[(order.indexOf(choice()) + 1) % 3];
      if (next === 'system') { delete root.dataset.theme; } else { root.dataset.theme = next; }
      try { localStorage.setItem('flux-theme', next); } catch (e) { /* storage can be blocked */ }
      var light = next === 'light' || (next === 'system' && window.matchMedia('(prefers-color-scheme: light)').matches);
      var meta = document.querySelector('meta[name="theme-color"]');
      if (meta) meta.setAttribute('content', light ? '#f5f5f5' : '#000000');
      paintTheme();
    });
    paintTheme();
  }

  /* ---------- nav hairline + scroll progress ---------- */
  var nav = document.getElementById('nav'), bar = document.getElementById('progress'), ticking = false;
  function onScroll() {
    ticking = false;
    var y = window.scrollY || 0;
    var max = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
    if (nav) nav.classList.toggle('scrolled', y > 10);
    if (bar) bar.style.transform = 'scaleX(' + Math.min(1, y / max).toFixed(4) + ')';
  }
  window.addEventListener('scroll', function () { if (!ticking) { ticking = true; requestAnimationFrame(onScroll); } }, { passive: true });
  onScroll();

  /* ---------- reveal on scroll ---------- */
  var reveals = document.querySelectorAll('.reveal');
  reveals.forEach(function (el) {
    var p = el.parentElement;
    if (p && /cols|rows|faq/.test(p.className)) {
      el.style.transitionDelay = Math.min(3, Array.prototype.indexOf.call(p.children, el)) * 90 + 'ms';
    }
  });
  if ('IntersectionObserver' in window && !staticMode) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) { if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); } });
    }, { threshold: 0.12, rootMargin: '0px 0px -6% 0px' });
    reveals.forEach(function (el) { io.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add('in'); });
  }

  /* ---------- 01: the copy / send / paste scene ---------- */
  var scene = document.getElementById('scene');
  if (scene) {
    var TEXT = 'https://github.com', LOOP = 8400;
    var $ = function (id) { return document.getElementById(id); };
    var typed = $('typed'), pasted = $('pasted'), caret1 = $('caret1'), caret2 = $('caret2');
    var sendBtn = $('sendBtn'), packet = $('packet'), toast = $('toast'), trail = $('trail');
    var beats = scene.querySelectorAll('.beats li');
    var X0 = 272, X1 = 628, dots = [];
    for (var k = 0; k < 7; k++) {
      var c = document.createElementNS(NS, 'circle');
      c.setAttribute('cy', 210); c.setAttribute('r', (6 - k * 0.65).toFixed(2)); c.setAttribute('fill', 'var(--red)'); c.setAttribute('opacity', 0);
      trail.appendChild(c); dots.push(c);
    }
    var ease = function (t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; };
    var clamp01 = function (v) { return Math.max(0, Math.min(1, v)); };

    function frame(t) {
      // 1. type on the phone
      var typing = clamp01((t - 400) / 1500);
      var fade = t > 7600 ? clamp01(1 - (t - 7600) / 500) : 1;
      typed.textContent = TEXT.slice(0, Math.round(typing * TEXT.length));
      typed.setAttribute('opacity', fade);
      var caretOn = t < 2000 && Math.floor(t / 450) % 2 === 0;
      caret1.setAttribute('opacity', caretOn ? 1 : 0);
      caret1.setAttribute('x', 30 + typed.textContent.length * 5.7);

      // 2. tap send
      var pulse = clamp01((t - 1900) / 300);
      sendBtn.style.transform = 'scale(' + (1 - 0.16 * Math.sin(pulse * Math.PI)).toFixed(3) + ')';

      // 3. the dot crosses the network
      var travel = clamp01((t - 2100) / 1100);
      var px = X0 + (X1 - X0) * ease(travel);
      var show = t >= 2100 && t < 3350;
      packet.setAttribute('cx', px.toFixed(1));
      packet.setAttribute('opacity', show ? 1 : 0);
      dots.forEach(function (d, i) {
        var tx = X0 + (X1 - X0) * ease(clamp01(travel - i * 0.045));
        d.setAttribute('cx', tx.toFixed(1));
        d.setAttribute('opacity', show ? (0.5 - i * 0.07).toFixed(2) : 0);
      });

      // 4. notification, then paste
      var toastIn = clamp01((t - 3300) / 300), toastOut = clamp01((t - 6800) / 400);
      toast.setAttribute('opacity', (toastIn * (1 - toastOut)).toFixed(2));
      toast.setAttribute('transform', 'translate(0 ' + (-8 * (1 - toastIn)).toFixed(1) + ')');
      var paste = clamp01((t - 4000) / 1200);
      pasted.textContent = TEXT.slice(0, Math.round(paste * TEXT.length));
      pasted.setAttribute('opacity', fade);
      caret2.setAttribute('opacity', t > 3900 && t < 7600 && Math.floor(t / 450) % 2 === 0 ? 1 : 0);
      caret2.setAttribute('x', 20 + pasted.textContent.length * 6.6);

      // 5. captions
      var active = t < 2000 ? 0 : (t < 3400 ? 1 : 2);
      beats.forEach(function (b, i) { b.classList.toggle('on', i === active && t >= 400); });
    }

    if (reduceMotion) {
      frame(5200);
      beats.forEach(function (b) { b.classList.add('on'); });
    } else {
      var running = false, visible = false, start = 0, rafId = 0;
      var loop = function (now) {
        if (!running) return;
        if (!start) start = now;
        frame((now - start) % LOOP);
        rafId = requestAnimationFrame(loop);
      };
      var sync = function () {
        var should = visible && !document.hidden;
        if (should && !running) { running = true; start = 0; rafId = requestAnimationFrame(loop); }
        if (!should && running) { running = false; cancelAnimationFrame(rafId); }
      };
      frame(0);
      new IntersectionObserver(function (es) { visible = es[0].isIntersecting; sync(); }, { threshold: 0.25 }).observe(scene);
      document.addEventListener('visibilitychange', sync);
    }
  }

  /* ---------- 02: sticky phone follows the feature list ---------- */
  var rowsEl = document.querySelectorAll('.feat');
  var stage = document.querySelector('.stage');
  function activate(row) {
    rowsEl.forEach(function (r) { r.classList.toggle('on', r === row); });
    if (!stage) return;
    var n = row.getAttribute('data-shot');
    stage.classList.toggle('show-widget', n === '3');
    stage.querySelectorAll('.shot').forEach(function (s) { s.classList.toggle('on', s.getAttribute('data-i') === n); });
  }
  if (rowsEl.length) {
    activate(rowsEl[0]);
    if ('IntersectionObserver' in window) {
      var fio = new IntersectionObserver(function (entries) {
        entries.forEach(function (en) { if (en.isIntersecting) activate(en.target); });
      }, { rootMargin: '-42% 0px -42% 0px', threshold: 0 });
      rowsEl.forEach(function (r) { fio.observe(r); });
    }
  }

  /* ---------- download links from the latest GitHub release ---------- */
  // Until a release exists, the buttons keep pointing at the releases page.
  fetch('https://api.github.com/repos/' + REPO + '/releases/latest', { headers: { Accept: 'application/vnd.github+json' } })
    .then(function (r) { return r.ok ? r.json() : Promise.reject(new Error('no release')); })
    .then(function (rel) {
      var assets = rel.assets || [];
      function pick(re) { return assets.find(function (a) { return re.test(a.name); }); }
      var map = {
        apk: pick(/arm64.*\.apk$/i) || pick(/\.apk$/i),
        apk32: pick(/(armeabi|armv7).*\.apk$/i),
        exe: pick(/\.exe$/i)
      };
      document.querySelectorAll('[data-dl]').forEach(function (a) {
        var asset = map[a.getAttribute('data-dl')];
        if (asset) a.setAttribute('href', asset.browser_download_url);
      });
      document.querySelectorAll('[data-size]').forEach(function (s) {
        var asset = map[s.getAttribute('data-size')];
        if (asset) s.textContent = Math.round(asset.size / 1048576) + ' MB';
      });
      if (rel.tag_name) document.querySelectorAll('[data-version]').forEach(function (v) { v.textContent = rel.tag_name; });
    })
    .catch(function () { /* offline or no release yet: keep the default links */ });
})();
