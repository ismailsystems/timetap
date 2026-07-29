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
 * Returns { pass, fail, failed, skipped }. Anything in fail is a regression.
 * A skipped check is one this state could not reach; it is never a pass.
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
  /* A check that could not run in this state. Named so the total still adds up
     to the number of checks the file contains, and never counted as a pass. */
  var skipped = [];
  function skip(name, why) { skipped.push({ name: name, why: why }); }

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
  /* The note is one box, in the NOW panel, belonging to whatever is running —
     it used to be one box per category. Still worth checking it survived the
     parser: an <input> written into a <button> is silently dropped, and that
     is the bug this check has always been about. */
  ok('the NOW panel has its note field',
    !!document.getElementById('note') &&
    document.getElementById('note').tagName === 'INPUT',
    'a <button> would have had the <input> stripped');
  ok('every category row has its clock',
    cats.every(function (c) { return !!c.querySelector('.ge'); }));
  ok('every category row has its colour swatch',
    cats.every(function (c) { return !!c.querySelector('.sw'); }));

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
  /* The two posture figures were dropped: the footer says the state in words
     with a dot beside it. Two channels still, so it does not rest on colour —
     the label changes as well as the dot. */
  var pdot = document.getElementById('postureDot');
  var plab = document.getElementById('postureLabel');
  ok('the posture state is shown as a dot and a word',
    !!pdot && !!plab && vis('postureDot') &&
    /SITTING/.test(plab.textContent),
    'dot=' + vis('postureDot') + ' label="' + (plab ? plab.textContent : '') + '"');

  /* STOP is the only control that ends the day. A day that cannot be ended is
     a phantom block every night, so "it rendered" is worth checking on its own
     — reachable, hittable, and named for a screen reader. */
  var stopBtn = document.getElementById('stopBtn');
  var stopRect = stopBtn ? stopBtn.getBoundingClientRect() : null;
  /* STOP shows only while a block runs — ending a day that has not started is
     not a thing to offer. So this checks that it exists and is named, and that
     WHEN it is displayed it is big enough to hit. */
  var stopShown = !!stopBtn && getComputedStyle(stopBtn).display !== 'none';
  ok('the STOP control exists, is reachable and carries a label',
    !!stopBtn && stopBtn.tagName === 'BUTTON' &&
    (!stopShown || (stopRect.width >= 44 && stopRect.height >= 44)) &&
    !!(stopBtn.getAttribute('aria-label') || stopBtn.textContent.trim()),
    stopBtn ? (stopBtn.tagName + ' ' + Math.round(stopRect.width) + 'x' +
               Math.round(stopRect.height) + ' label="' +
               (stopBtn.getAttribute('aria-label') || stopBtn.textContent.trim()) + '"')
            : 'no #stopBtn in the document');

  var pageBg = getComputedStyle(document.body).backgroundColor;
  var lit = cats.filter(function (c) { return c.classList.contains('active'); })[0];
  if (lit) {
    var ring = getComputedStyle(lit).boxShadow;
    ok('the lit ring is not the colour of the page', ring.indexOf(pageBg) < 0, ring);
    ok('the lit ring sits outside the box, not inset', ring.indexOf('inset') < 0, ring);
  } else {
    // Not "a check that passed": a check that did not run. Reporting it as a
    // pass is the vacuous-assertion bug this file's own header warns about, and
    // it makes the total underivable — you cannot tell a skipped check from a
    // real one once both are counted the same way.
    skip('the lit ring is not the colour of the page', 'no block running');
    skip('the lit ring sits outside the box, not inset', 'no block running');
  }

  // ── geometry ────────────────────────────────────────────────────
  var widths = {};
  cats.forEach(function (c) { widths[px(c.getBoundingClientRect().width)] = 1; });
  ok('every category row is the same width', Object.keys(widths).length === 1,
    Object.keys(widths).join(' / '));
  var heights = {};
  cats.forEach(function (c) { heights[px(c.getBoundingClientRect().height)] = 1; });
  ok('every category row is the same height regardless of state',
    Object.keys(heights).length === 1, Object.keys(heights).join(' / '));
  /* One column, so there is no column count to get wrong and no slot to leave
     empty. The tile grid had both, and both cost real bugs. */
  ok('the categories are one column',
    cats.every(function (c) {
      return Math.abs(c.getBoundingClientRect().left - cats[0].getBoundingClientRect().left) < 1;
    }), 'rows must share a left edge');
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

  /* ── the clocks are actually tabular ─────────────────────────────
   *
   * .tnum is applied correctly everywhere and did almost nothing. The `font:`
   * SHORTHAND resets font-variant-numeric to normal, and nearly every rule that
   * styles a clock sets it — most of them from an ID selector, which outranks
   * .tnum however the source is ordered. Only #undoChip survived, because it
   * has no shorthand of its own. The 48px headline timer was affected, which is
   * the one place on the screen where digits changing width is impossible to
   * miss: the elapsed time visibly jitters every second.
   *
   * Measured computed, on every element carrying the class, so an element added
   * later with a shorthand of its own is caught rather than assumed. */
  var tnums = [].slice.call(document.querySelectorAll('.tnum'));
  ok('there are clocks on this screen to check', tnums.length > 0, String(tnums.length));
  var flat = tnums.filter(function (el) {
    return getComputedStyle(el).fontVariantNumeric.indexOf('tabular-nums') < 0;
  }).map(function (el) {
    return (el.id || el.className) + '=' + getComputedStyle(el).fontVariantNumeric;
  });
  ok('every element carrying .tnum computes to tabular-nums', flat, flat.join(' '));

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
  if (skipped.length) console.table(skipped);
  return { pass: pass, fail: fail.length, failed: fail, skipped: skipped };
})();
