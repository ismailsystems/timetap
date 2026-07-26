/**
 * Browser smoke check. Paste into the console with the app open.
 *
 * test/tests.js is thorough about logic and structurally blind to three things,
 * each of which has shipped a bug:
 *
 *   CSS cascade      both posture figures on screen at once, because
 *                    "#postureBtn svg" outranks "#icSit"
 *   viewport         100vh overriding 100dvh, so the app was taller than the
 *                    screen and ran off the bottom behind the toolbar
 *   HTML parsing     an <input> written into a <button>, which the parser drops
 *
 * None of those is reachable without a real engine, a real cascade and a real
 * viewport. This is the cheapest thing that has all three. Every check below
 * corresponds to a bug that actually shipped.
 *
 * Returns { pass, fail, checks }. Anything in fail is a regression.
 */
(function () {
  var out = [], px = function (n) { return Math.round(n); };
  /* An empty array is truthy, so a check that reports its offenders as a list
     would pass whatever it found. Arrays are judged by length, booleans by
     themselves, and anything else is a mistake worth shouting about. */
  function ok(name, cond, detail) {
    var pass;
    if (Array.isArray(cond)) pass = cond.length === 0;
    else if (typeof cond === 'boolean') pass = cond;
    else pass = false;
    out.push({ name: name, pass: pass, detail: detail || '' });
  }

  var app = document.getElementById('app');
  var grid = document.getElementById('grid');
  var cells = grid ? [].slice.call(grid.children) : [];
  var cats = cells.filter(function (c) { return c.dataset.key; });

  // ── the page actually built ──────────────────────────────────────
  ok('#app exists', !!app);
  ok('the grid has cells', cells.length > 0, String(cells.length));
  ok('every category cell has a label',
    cats.every(function (c) {
      var k = c.querySelector('.k');
      return k && k.textContent.trim();
    }), cats.length + ' cells');
  ok('every category cell has its note field',
    cats.every(function (c) { return !!c.querySelector('.gn'); }),
    'a <button> would have had the <input> stripped');
  ok('every category cell has its clock',
    cats.every(function (c) { return !!c.querySelector('.ge'); }));

  // ── viewport ────────────────────────────────────────────────────
  var h = app ? app.getBoundingClientRect().height : 0;
  ok('the app is exactly as tall as the viewport', Math.abs(h - window.innerHeight) <= 2,
    px(h) + ' vs ' + window.innerHeight);
  ok('nothing scrolls horizontally',
    document.documentElement.scrollWidth <= window.innerWidth + 1,
    document.documentElement.scrollWidth + ' vs ' + window.innerWidth);
  ok('nothing scrolls vertically',
    document.documentElement.scrollHeight <= window.innerHeight + 2,
    document.documentElement.scrollHeight + ' vs ' + window.innerHeight);

  // ── the cascade ─────────────────────────────────────────────────
  var vis = function (id) {
    var e = document.getElementById(id);
    return e && getComputedStyle(e).display !== 'none';
  };
  ok('exactly one posture figure is visible',
    (vis('icSit') ? 1 : 0) + (vis('icStand') ? 1 : 0) === 1,
    'sit=' + vis('icSit') + ' stand=' + vis('icStand'));

  var pageBg = getComputedStyle(document.body).backgroundColor;
  var lit = cats.filter(function (c) { return c.classList.contains('active'); })[0];
  if (lit) {
    var ring = getComputedStyle(lit).boxShadow;
    ok('the lit ring is not the colour of the page', ring.indexOf(pageBg) < 0, ring);
    ok('the lit ring sits outside the box, not inset', ring.indexOf('inset') < 0, ring);
  } else {
    ok('no block running, ring not checked', true, 'tap a category and re-run');
  }

  // ── geometry ────────────────────────────────────────────────────
  var widths = {};
  cells.forEach(function (c) { widths[px(c.getBoundingClientRect().width)] = 1; });
  ok('every cell is the same width', Object.keys(widths).length === 1,
    Object.keys(widths).join(' / '));
  var heights = {};
  cells.forEach(function (c) { heights[px(c.getBoundingClientRect().height)] = 1; });
  ok('every cell is the same height regardless of state',
    Object.keys(heights).length === 1, Object.keys(heights).join(' / '));
  // Derived, not hardcoded: the column count changes above ten categories, and
  // a check that assumes two would fail on a grid that is perfectly correct.
  var cols = getComputedStyle(grid).gridTemplateColumns.split(' ').length;
  ok('every row is full', cells.length % cols === 0, cells.length + ' cells / ' + cols + ' cols');
  /* Wrapping is not overflow, so the width check above passes happily while a
     word is being sliced in half. "Fragments" rendering as "Fragmen ts" is the
     shape of this bug. A label may use as many lines as it has words, no more. */
  function lineCount(k) {
    var cs = getComputedStyle(k);
    var lh = parseFloat(cs.lineHeight);
    if (!lh || isNaN(lh)) lh = parseFloat(cs.fontSize) * 1.2;
    // The box includes its padding; only the content is made of lines.
    var content = k.getBoundingClientRect().height
      - parseFloat(cs.paddingTop) - parseFloat(cs.paddingBottom);
    return Math.max(1, Math.round(content / lh));
  }
  /* A word may only be broken if it could not have fitted. "Fragments" at
     19px in a 137px cell fits and must not be split; "Correspondence" does not
     fit at any legible size and breaking it is the least bad option. */
  function widestWordFits(k) {
    var cs = getComputedStyle(k);
    var probe = document.createElement('span');
    probe.style.cssText = 'position:absolute;visibility:hidden;white-space:pre;font:' + cs.font;
    document.body.appendChild(probe);
    var room = k.getBoundingClientRect().width
      - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
    var fits = k.textContent.trim().split(/\s+/).every(function (w) {
      probe.textContent = w;
      return probe.getBoundingClientRect().width <= room + 1;
    });
    probe.remove();
    return fits;
  }
  var split = cats.filter(function (c) {
    var k = c.querySelector('.k');
    return lineCount(k) > k.textContent.trim().split(/\s+/).length && widestWordFits(k);
  }).map(function (c) { return c.querySelector('.k').textContent; });
  ok('no word is broken that had room to fit', split, split.join(' '));

  /* The check above measures against whatever padding is currently set, so it
     excuses a break that the padding itself caused — which is exactly how
     "Fragments" came to render as "Fragmen ts". This one is absolute: a short
     label gets one line at any column count, or the styling is wrong. */
  var cramped = cats.filter(function (c) {
    var k = c.querySelector('.k'), text = k.textContent.trim();
    // Single words only: "Deep work" wrapping at its space is correct.
    return text.length <= 10 && !/\s/.test(text) && lineCount(k) > 1;
  }).map(function (c) { return c.querySelector('.k').textContent; });
  ok('a single word of ten characters or fewer gets one line', cramped, cramped.join(' '));

  ok('the label fits the column it was given',
    cats.every(function (c) {
      var k = c.querySelector('.k');
      return k.scrollWidth <= k.clientWidth + 1 &&
             k.getBoundingClientRect().height <= c.getBoundingClientRect().height - 20;
    }),
    cats.map(function (c) {
      var k = c.querySelector('.k');
      return k.textContent + ':' + px(k.getBoundingClientRect().height);
    }).join(' '));

  // ── touch targets and the safe area ─────────────────────────────
  var footRoom = window.innerHeight - (document.getElementById('postureRow')
    ? document.getElementById('postureRow').getBoundingClientRect().bottom : window.innerHeight);
  ok('the bottom row clears the home indicator', footRoom >= 20, px(footRoom) + 'px');
  ok('every category cell is a comfortable target',
    cats.every(function (c) {
      var r = c.getBoundingClientRect();
      return r.width >= 44 && r.height >= 44;
    }));

  var pass = out.filter(function (c) { return c.pass; }).length;
  var fail = out.filter(function (c) { return !c.pass; });
  console.table(out);
  return { pass: pass, fail: fail.length, failed: fail };
})();
