/* Flux landing page: dot-matrix text, theme switch, reveal on scroll, live download links. */
(function () {
  'use strict';

  var REPO = 'Shreyashkolhe22/Flux';
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

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
    '0': '01110 10001 10011 10101 11001 10001 01110', '1': '00100 01100 00100 00100 00100 00100 01110',
    '2': '01110 10001 00001 00010 00100 01000 11111', '3': '11110 00001 00001 01110 00001 00001 11110',
    '4': '00010 00110 01010 10010 11111 00010 00010', '5': '11111 10000 11110 00001 00001 10001 01110',
    '6': '00110 01000 10000 11110 10001 10001 01110', '7': '11111 00001 00010 00100 01000 01000 01000',
    '8': '01110 10001 10001 01110 10001 10001 01110', '9': '01110 10001 10001 01111 00001 00010 01100',
    '.': '0 0 0 0 0 0 1', ' ': '00 00 00 00 00 00 00'
  };
  var NS = 'http://www.w3.org/2000/svg';

  function drawDots(el) {
    var text = (el.getAttribute('data-text') || '').toUpperCase();
    var thin = el.hasAttribute('data-thin');
    var animate = el.classList.contains('dots-hero') || el.classList.contains('num') || el.classList.contains('gnum');
    var circles = [];
    var x = 0, index = 0;
    var svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('aria-hidden', 'true');
    for (var i = 0; i < text.length; i++) {
      var rows = (G[text[i]] || '').split(' ');
      if (!rows[0]) continue;
      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < rows[r].length; c++) {
          if (rows[r][c] !== '1') continue;
          var isStop = text[i] === '.';
          var dot = document.createElementNS(NS, 'circle');
          var radius = isStop ? 0.5 : (el.classList.contains('dots-hero') ? 0.25 : (thin ? 0.3 : 0.4));
          dot.setAttribute('cx', x + c + 0.5);
          dot.setAttribute('cy', r + 0.5);
          dot.setAttribute('r', radius);
          dot.setAttribute('class', isStop ? 'r' : 'd');
          if (animate && !reduceMotion) {
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
    var pending = null;
    window.addEventListener('pointermove', function (e) {
      pending = e;
      if (hero._raf) return;
      hero._raf = requestAnimationFrame(function () {
        hero._raf = 0;
        var box = hero.getBoundingClientRect();
        if (!pending || box.width === 0) return;
        var scale = box.width / (hero._svg.viewBox.baseVal.width || 1);
        var px = (pending.clientX - box.left) / scale;
        var py = (pending.clientY - box.top) / scale;
        var reach = 3.4;
        for (var i = 0; i < hero._dots.length; i++) {
          var d = hero._dots[i];
          var dist = Math.hypot(d.cx - px, d.cy - py);
          var k = dist < reach ? 1 + (1 - dist / reach) * 0.85 : 1;
          d.node.setAttribute('r', (d.r * k).toFixed(3));
        }
      });
    }, { passive: true });
  }

  /* ---------- theme: System / Light / Dark ---------- */
  var root = document.documentElement;
  var buttons = document.querySelectorAll('[data-set-theme]');

  function currentChoice() {
    return root.dataset.theme === 'light' || root.dataset.theme === 'dark' ? root.dataset.theme : 'system';
  }
  function paintButtons() {
    var choice = currentChoice();
    buttons.forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.setTheme === choice)); });
  }
  buttons.forEach(function (b) {
    b.addEventListener('click', function () {
      var t = b.dataset.setTheme;
      if (t === 'system') { delete root.dataset.theme; } else { root.dataset.theme = t; }
      try { localStorage.setItem('flux-theme', t); } catch (e) { /* storage can be blocked */ }
      var meta = document.querySelector('meta[name="theme-color"]');
      if (meta) {
        var light = t === 'light' || (t === 'system' && window.matchMedia('(prefers-color-scheme: light)').matches);
        meta.setAttribute('content', light ? '#f5f5f5' : '#000000');
      }
      paintButtons();
    });
  });
  paintButtons();

  /* ---------- reveal on scroll ---------- */
  var reveals = document.querySelectorAll('.reveal');
  reveals.forEach(function (el, i) {
    var parent = el.parentElement;
    if (parent && /steps|grid|dl-grid/.test(parent.className)) {
      el.style.transitionDelay = (Array.prototype.indexOf.call(parent.children, el) % 3) * 90 + 'ms';
    }
  });
  // ?reveal=off shows everything at once with a fixed hero height (for screenshots and testing).
  if (location.search.indexOf('reveal=off') > -1) document.documentElement.classList.add('static');
  if ('IntersectionObserver' in window && location.search.indexOf('reveal=off') === -1) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -6% 0px' });
    reveals.forEach(function (el) { io.observe(el); });
  } else {
    reveals.forEach(function (el) { el.classList.add('in'); });
  }

  /* ---------- download links from the latest GitHub release ---------- */
  // Until a release exists, the buttons keep pointing at the releases page.
  fetch('https://api.github.com/repos/' + REPO + '/releases/latest', {
    headers: { Accept: 'application/vnd.github+json' }
  })
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
      if (rel.tag_name) {
        document.querySelectorAll('[data-version]').forEach(function (v) { v.textContent = rel.tag_name; });
      }
    })
    .catch(function () { /* offline or no release yet: keep the default links */ });

  /* ---------- mobile menu ---------- */
  var menuBtn = document.getElementById("menuBtn"), menu = document.getElementById("menu");
  function setMenu(open) {
    if (!menuBtn || !menu) return;
    menu.hidden = !open;
    menuBtn.setAttribute("aria-expanded", String(open));
    menuBtn.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    document.documentElement.classList.toggle("menu-open", open);
  }
  if (menuBtn && menu) {
    menuBtn.addEventListener("click", function () { setMenu(menu.hidden); });
    menu.addEventListener("click", function (e) { if (e.target.closest("a")) setMenu(false); });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") setMenu(false); });
    window.addEventListener("resize", function () { if (window.innerWidth > 980) setMenu(false); });
  }
})();
