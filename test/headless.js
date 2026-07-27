#!/usr/bin/env node
/*
 * The layer that has seen a pixel, without a human holding a phone.
 *
 * It builds the document the way Apps Script builds it, renders it in a real
 * browser engine, and runs the real checks from test/smoke.js inside the page.
 * The checks are not reimplemented here: there is one copy of them and this
 * loads it.
 *
 * It does not replace the phone paste. Two of the three bug classes smoke.js
 * exists for have only ever appeared on real hardware, and a desktop engine
 * cannot see those.
 *
 * Dev-only. Nothing here is deployed; the four source files import nothing.
 */
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const SMOKE = path.join(__dirname, 'smoke.js');

/*
 * The meta tags this harness injects, written out in full and deliberately not
 * read from doGet.
 *
 * Deriving them from doGet would make the comparison self-fulfilling: whatever
 * doGet sent would be whatever we injected, and the rendered page would agree
 * with it by construction while nothing was actually pinned. This is the second
 * copy on purpose, and test/lint.js fails when it drifts from the first.
 *
 * Apps Script ignores meta tags written into the HTML file and permits only
 * four names through addMetaTag, so this list is not the place to get creative.
 */
const META_TAGS = [
  ['viewport', 'width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no'],
  ['apple-mobile-web-app-capable', 'yes'],
  ['mobile-web-app-capable', 'yes']
];
const INSTALL_PKG = 'npm install';
const INSTALL_BROWSER = 'npx playwright install chromium';

/* A skipped run is never a pass, so every exit from here is non-zero. */
function fail(lines) {
  console.error('\n' + [].concat(lines).join('\n') + '\n');
  process.exit(1);
}

function loadPlaywright() {
  try {
    return require('playwright');
  } catch (e) {
    fail(['The headless layer needs Playwright and it is not installed.',
          '',
          '    ' + INSTALL_PKG,
          '',
          'It is a dev dependency. The four source files stay dependency-free.']);
  }
}

/** What a phone would receive, produced by the real doGet. */
function served() {
  try {
    return JSON.parse(execFileSync(process.execPath, [path.join(__dirname, 'serve.js')],
                                   { cwd: ROOT, encoding: 'utf8' }));
  } catch (e) {
    fail(['Could not work out what doGet serves:', '', String((e && e.message) || e)]);
  }
}

/**
 * How many checks smoke.js contains, counted from the file rather than written
 * down here. A number typed in by hand goes stale the first time someone adds a
 * check, and the run would then pass while quietly not running it.
 */
function countChecks() {
  const src = fs.readFileSync(SMOKE, 'utf8');
  return (src.match(/\bok\(\s*'/g) || []).length;
}

const esc = s => String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');

/**
 * Apps Script serves a fragment wrapped in its own document, with the meta tags
 * from addMetaTag injected into the head — it ignores any meta written into the
 * HTML file itself. Rebuilding the wrapper here is the whole point of the
 * exercise: a document assembled any other way is not the one the phone loads.
 *
 * Note there is no charset meta. Adding one would be a tag doGet never sends,
 * and the meta list has to match it exactly.
 */
function documentFor(page, withMetas) {
  const metas = withMetas
    ? META_TAGS.map(m => '  <meta name="' + esc(m[0]) + '" content="' + esc(m[1]) + '">').join('\n')
    : '';
  return '<!doctype html>\n<html>\n<head>\n' + metas +
         '\n  <title>' + esc(page.title) + '</title>\n</head>\n<body>\n' +
         page.html + '\n</body>\n</html>';
}

/**
 * Render once and report what the live DOM says.
 *
 * `metaTiming` is 'before' or 'after'. 'after' exists to prove the injection
 * point is load-bearing rather than decorative: a viewport meta added once the
 * page has already been laid out does not lay it out again.
 */
async function renderOnce(browser, view, page, metaTiming) {
  const ctx = await browser.newContext({
    viewport: { width: view.width, height: view.height },
    isMobile: !!view.isMobile,
    hasTouch: !!view.isMobile,
    deviceScaleFactor: view.isMobile ? 3 : 1
  });
  const pg = await ctx.newPage();
  const errors = [];
  pg.on('pageerror', e => errors.push(String((e && e.message) || e)));

  await pg.setContent(documentFor(page, metaTiming === 'before'), { waitUntil: 'load' });

  if (metaTiming === 'after') {
    await pg.evaluate(metas => {
      metas.forEach(m => {
        const el = document.createElement('meta');
        el.setAttribute('name', m[0]);
        el.setAttribute('content', m[1]);
        document.head.appendChild(el);
      });
    }, META_TAGS);
  }

  const metas = await pg.evaluate(() =>
    [].slice.call(document.querySelectorAll('meta'))
      .map(m => [m.getAttribute('name'), m.getAttribute('content')]));
  const layoutWidth = await pg.evaluate(() => document.documentElement.clientWidth);
  const cells = await pg.locator('#grid [data-key]').count();
  const smoke = await pg.evaluate(fs.readFileSync(SMOKE, 'utf8'));

  await ctx.close();
  return { metas, layoutWidth, cells, smoke, errors };
}

/**
 * The drawer of set-aside writes, driven at real coordinates.
 *
 * This is the one thing the offline suite structurally cannot check. Its DOM shim
 * has no layout, so it cannot express a control moving into the place a finger has
 * already committed to — which is exactly how a single-tap DISCARD used to destroy
 * a second write the reader had never looked at: discarding a row let the rows
 * below slide up, and the next row's button landed under the second tap of an
 * ordinary double tap.
 *
 * So this runs the gesture rather than the logic: two clicks at one fixed point,
 * 120ms apart, and asserts that exactly one entry left and that it was the one
 * aimed at. Contract assertion 24.
 *
 * It needs a real origin, because localStorage on the about:blank document that
 * setContent produces is not the same store the page reads. That is why the meta
 * and smoke checks above keep using setContent and this does not: they are
 * checking different things, and only this one needs to write to storage first.
 */
const DRAWER_ORIGIN = 'http://timetap.invalid/';
const DEAD_SEED = [
  { at: 1, why: 'oldest — must survive',  key: 'ADM', startMs: 1, op: { id: 'a', type: 'setMark',     ref: 'r1' } },
  { at: 2, why: 'middle — must survive',  key: 'DW',  startMs: 2, op: { id: 'b', type: 'closeActual', ref: 'r2' } },
  { at: 3, why: 'newest — the target',    key: 'MTG', startMs: 3, op: { id: 'c', type: 'setMark',     ref: 'r3' } }
];

/* A server that always succeeds with an empty day, so boot() takes the healthy
   path instead of stopping at "google.script.run unavailable". */
function serverStub() {
  const mk = () => {
    const b = {
      withSuccessHandler: f => (b._ok = f, b),
      withFailureHandler: f => (b._fail = f, b),
      applyOps: () => setTimeout(() => b._ok && b._ok({ applied: [], errors: [], dropped: [] }), 5),
      getState: () => setTimeout(() => b._ok && b._ok({ open: null, today: [], sit: null, sitToday: [] }), 5),
      addCategory: () => setTimeout(() => b._ok && b._ok({}), 5)
    };
    return b;
  };
  window.google = { script: { run: new Proxy({}, { get: (_, k) => (...a) => mk()[k](...a) }) } };
}

async function checkDrawer(browser, view, page) {
  const problems = [];
  const ctx = await browser.newContext({
    viewport: { width: view.width, height: view.height },
    isMobile: !!view.isMobile, hasTouch: !!view.isMobile,
    deviceScaleFactor: view.isMobile ? 3 : 1
  });
  const pg = await ctx.newPage();
  const errors = [];
  pg.on('pageerror', e => errors.push(String((e && e.message) || e)));
  try {
    await pg.route(DRAWER_ORIGIN, r =>
      r.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: documentFor(page, true) }));
    await pg.addInitScript(serverStub);
    await pg.addInitScript(d => localStorage.setItem('tt.dead.v1', JSON.stringify(d)), DEAD_SEED);
    await pg.goto(DRAWER_ORIGIN, { waitUntil: 'load' });
    await pg.waitForTimeout(300);

    const read = () => pg.evaluate(() =>
      JSON.parse(localStorage.getItem('tt.dead.v1') || '[]').map(e => e.why));

    const banner = pg.locator('#err');
    if (!await banner.isVisible()) {
      problems.push('drawer: the banner is not visible with three writes set aside');
      return problems;
    }
    await banner.click();
    await pg.waitForTimeout(150);
    if (!await pg.locator('#sheetDead').isVisible()) {
      problems.push('drawer: tapping the banner did not open it');
      return problems;
    }

    const rows = pg.locator('#deadList .deadrow');
    const count = await rows.count();
    console.log('\ndrawer (' + view.name + ')');
    console.log('  rows:            ' + count);
    if (count !== DEAD_SEED.length) {
      problems.push('drawer: ' + count + ' rows for ' + DEAD_SEED.length + ' set-aside writes');
      return problems;
    }

    const target = (await rows.nth(0).innerText()).split('\n')[2];
    const box = await rows.nth(0).locator('button.danger').boundingBox();
    const x = Math.round(box.x + box.width / 2), y = Math.round(box.y + box.height / 2);
    console.log('  double tap at:   ' + x + ',' + y + '  (aimed at "' + target + '")');

    await pg.mouse.click(x, y);
    await pg.waitForTimeout(120);
    await pg.mouse.click(x, y);
    await pg.waitForTimeout(250);

    const left = await read();
    console.log('  left after it:   ' + JSON.stringify(left));
    const gone = DEAD_SEED.map(d => d.why).filter(w => !left.includes(w));
    if (gone.length !== 1) {
      problems.push('drawer: a double tap at one point discarded ' + gone.length +
                    ' writes — ' + JSON.stringify(gone) + '. A tap must only ever ' +
                    'affect the row it was aimed at.');
    } else if (gone[0] !== target) {
      problems.push('drawer: the double tap discarded "' + gone[0] + '" but was aimed at "' +
                    target + '"');
    }
    if (errors.length) problems.push('drawer: the page threw: ' + errors.join(' | '));
  } finally {
    await ctx.close();
  }
  return problems;
}

/**
 * The same drawer, counted rather than watched: what does N taps on one fixed
 * point actually destroy?
 *
 * checkDrawer above pins the ordinary accident — one double tap, one entry gone,
 * and it is the entry aimed at. This phase pins the property underneath it, which
 * is what contract assertion 24 names after amendment A4: rows DO slide up when
 * one is removed, and what keeps that safe is that DISCARD arms on the first tap
 * and acts on the second. So a run of taps at one point destroys one entry per
 * *pair* of taps, and — the part that actually matters — every destruction is
 * preceded, at that same coordinate, by a button already reading TAP AGAIN TO
 * DISCARD. Nothing is ever destroyed by a tap onto an unarmed button.
 *
 * Freezing the layout would also have prevented the original bug and is not what
 * the build does; see amendment A4 in factory/HANDOFF.md for why it was rejected.
 * A check that asserted the layout stood still would pass on a build that does not
 * exist and fail on the one that does.
 */
const TAP_COUNTS = [2, 3, 4, 6];
const TAP_SEED_SIZE = 5;
const tapSeed = () => Array.from({ length: TAP_SEED_SIZE }, (_, i) => ({
  at: i + 1, why: 'entry-' + (i + 1), key: 'K' + i, startMs: i + 1,
  op: { id: String(i), type: 'setMark', ref: 'r' + i }
}));

/** Open the drawer on a freshly seeded page and hand back the page. */
async function openDrawerWith(ctx, page, seed) {
  const pg = await ctx.newPage();
  const errors = [];
  pg.on('pageerror', e => errors.push(String((e && e.message) || e)));
  await pg.route(DRAWER_ORIGIN, r =>
    r.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: documentFor(page, true) }));
  await pg.addInitScript(serverStub);
  await pg.addInitScript(d => localStorage.setItem('tt.dead.v1', JSON.stringify(d)), seed);
  await pg.goto(DRAWER_ORIGIN, { waitUntil: 'load' });
  await pg.waitForTimeout(300);
  await pg.locator('#err').click();
  await pg.waitForTimeout(150);
  return { pg, errors };
}

async function tapNTimes(browser, view, page, taps) {
  const ctx = await browser.newContext({
    viewport: { width: view.width, height: view.height },
    isMobile: !!view.isMobile, hasTouch: !!view.isMobile,
    deviceScaleFactor: view.isMobile ? 3 : 1
  });
  try {
    const { pg, errors } = await openDrawerWith(ctx, page, tapSeed());
    const left = () => pg.evaluate(() =>
      JSON.parse(localStorage.getItem('tt.dead.v1') || '[]').map(e => e.why));

    const box = await pg.locator('#deadList .deadrow').nth(0).locator('button.danger').boundingBox();
    if (!box) return { trace: [], end: [], destroyed: 0, errors: errors.concat('no DISCARD button to aim at') };
    const x = Math.round(box.x + box.width / 2), y = Math.round(box.y + box.height / 2);

    const trace = [];
    for (let i = 0; i < taps; i++) {
      const before = await left();
      // What the button under the finger says *before* this tap lands. This is
      // the whole check: a tap that destroys must find an armed button here.
      const said = await pg.evaluate(([px, py]) => {
        const el = document.elementFromPoint(px, py);
        const btn = el && el.closest ? el.closest('button.danger') : null;
        return btn ? btn.textContent : '(nothing under the finger)';
      }, [x, y]);
      await pg.mouse.click(x, y);
      await pg.waitForTimeout(90);
      const after = await left();
      trace.push({ tap: i + 1, said: said, destroyed: before.length - after.length });
    }
    await pg.waitForTimeout(200);
    const end = await left();
    return { trace, end, at: x + ',' + y, destroyed: TAP_SEED_SIZE - end.length, errors };
  } finally {
    await ctx.close();
  }
}

async function checkTapCount(browser, view, page) {
  const problems = [];
  console.log('\ntap count on one fixed point (' + view.name + ', ' +
              TAP_SEED_SIZE + ' set aside)');
  for (const taps of TAP_COUNTS) {
    const r = await tapNTimes(browser, view, page, taps);
    const want = Math.floor(taps / 2);
    console.log('  ' + String(taps).padStart(2) + ' taps at ' + (r.at || '?') +
                ' -> ' + r.destroyed + ' destroyed (expected ' + want + '), left ' +
                JSON.stringify(r.end));

    const unarmed = r.trace.filter(t => t.destroyed > 0 && t.said !== 'TAP AGAIN TO DISCARD');
    if (unarmed.length) {
      problems.push('tap count: with ' + taps + ' taps at one point, ' + unarmed.length +
                    ' entr' + (unarmed.length === 1 ? 'y was' : 'ies were') +
                    ' destroyed by a tap onto a button that had not armed the row first:\n' +
                    unarmed.map(t => '    - tap ' + t.tap + ' destroyed ' + t.destroyed +
                                     ' while the button said ' + JSON.stringify(t.said)).join('\n'));
    }
    if (r.destroyed !== want) {
      problems.push('tap count: ' + taps + ' taps at one point destroyed ' + r.destroyed +
                    ' entries, not the ' + want + ' that arm/confirm allows. Trace:\n' +
                    r.trace.map(t => '    - tap ' + t.tap + ': button said ' +
                                     JSON.stringify(t.said) + ' -> destroyed ' + t.destroyed).join('\n'));
    }
    if (r.errors.length) problems.push('tap count: at ' + taps + ' taps the page threw: ' +
                                       r.errors.join(' | '));
  }
  return problems;
}

/** Same list, same content strings, order not meaningful. */
/*
 * A4 — the posture row in the worst case it ever has to survive.
 *
 * In the common case that row holds one thing: #sync is hidden when everything
 * is synced and #sitEdit is hidden when nothing is sitting. The case worth
 * pinning is the other one — pending writes AND sitting AND the sit clock AND
 * STOP, four things in a fixed 72px row on a 390px phone. That is the state a
 * day actually ends in, and STOP is the control that ends it.
 *
 * The failure this exists to catch is not a logic failure. It is a control that
 * passes every assertion in tests.js and is still too small, too cramped or too
 * ambiguous to use at 23:00. An unnoticed armed STOP is a stop that does not
 * happen.
 *
 * The states are driven rather than faked: the block and the SIT come from
 * seeded state the way a reload gets them, and the mark strip is reached by
 * actually ending a 40-minute block with STOP.
 */
const POSTURE_ORIGIN = 'http://timetap-posture.invalid/';
const TOUCH_TARGET = 44;

/* A server that accepts the call and never answers, so the row stays in its
   pending state for the length of the check. A stub that succeeded would empty
   the queue and hide #sync, which is the easy case, not the worst one. */
function stallingServerStub() {
  const mk = () => {
    const b = {
      withSuccessHandler: () => b,
      withFailureHandler: () => b,
      applyOps: () => {},
      getState: () => {},
      addCategory: () => {}
    };
    return b;
  };
  window.google = { script: { run: new Proxy({}, { get: (_, k) => (...a) => mk()[k](...a) }) } };
}

async function checkPostureRow(browser, view, page) {
  const problems = [];
  const label = view.name + ' ' + view.width + 'px';
  const ctx = await browser.newContext({
    viewport: { width: view.width, height: view.height },
    isMobile: !!view.isMobile, hasTouch: !!view.isMobile,
    deviceScaleFactor: view.isMobile ? 3 : 1
  });
  const pg = await ctx.newPage();
  const errors = [];
  pg.on('pageerror', e => errors.push(String((e && e.message) || e)));
  try {
    await pg.route(POSTURE_ORIGIN, r =>
      r.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: documentFor(page, true) }));
    await pg.addInitScript(stallingServerStub);
    await pg.addInitScript(() => {
      const now = Date.now();
      // A block running 40 minutes, so ending it is over MIN_MARK_MINUTES and
      // brings up the mark strip, and a SIT that has been open for an hour.
      localStorage.setItem('tt.state.v1', JSON.stringify({
        open: { ref: 'aaaabbbbccccdddd', key: 'DW', text: '', startMs: now - 40 * 60000 },
        sit: { ref: 'eeeeffff11112222', startMs: now - 60 * 60000 },
        lastTapMs: 0
      }));
      // Pending writes, so #sync is visible rather than hidden.
      localStorage.setItem('tt.queue.v1', JSON.stringify([
        { id: 'q1', type: 'setMark', ref: 'aaaabbbbccccdddd', mark: '-', ts: now },
        { id: 'q2', type: 'setText', ref: 'aaaabbbbccccdddd', text: 'x', ts: now }
      ]));
    });
    await pg.goto(POSTURE_ORIGIN, { waitUntil: 'load' });
    await pg.waitForTimeout(120);

    const geom = () => pg.evaluate(({ TOUCH_TARGET }) => {
      const vis = el => {
        if (!el) return false;
        const s = getComputedStyle(el);
        if (s.display === 'none' || s.visibility === 'hidden') return false;
        const r = el.getBoundingClientRect();
        return r.width > 0 && r.height > 0;
      };
      const posture = document.getElementById('posture');
      const row = document.getElementById('postureRow');
      const kids = posture ? [].slice.call(posture.children).filter(vis) : [];
      const rect = el => { const r = el.getBoundingClientRect();
                           return { x: r.left, y: r.top, w: r.width, h: r.height, r: r.right, b: r.bottom }; };
      const controls = kids.filter(el => el.matches('button, a, input, [role="button"]'));
      const stop = document.getElementById('stopBtn');
      /* The strip is the other thing that occupies this row, and its controls
         are two levels deep so no direct-children filter reaches them.
         Measured and reported rather than asserted: criterion 1 is about the
         resting posture row, and the strip is hidden then. See Q8. */
      const stripCtl = [].slice.call(document.querySelectorAll(
        '#strip .strip-marks button, #stripHead')).map(el => {
          const r = el.getBoundingClientRect();
          return { id: el.id || ('mark ' + el.textContent.trim()),
                   w: +r.width.toFixed(1), h: +r.height.toFixed(1) };
        });
      const lab = document.getElementById('postureLabel');
      const labStyle = lab ? getComputedStyle(lab) : null;
      const stopStyle = stop ? getComputedStyle(stop) : null;
      let hitStop = null;
      if (stop && vis(stop)) {
        const r = stop.getBoundingClientRect();
        const el = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
        hitStop = el ? (el.id || (el.closest('button') && el.closest('button').id) || el.tagName) : null;
      }
      return {
        rowRect: row ? rect(row) : null,
        postureRect: posture ? rect(posture) : null,
        postureHidden: posture ? posture.classList.contains('hidden') : null,
        stripHidden: (() => { const s = document.getElementById('strip');
                              return s ? s.classList.contains('hidden') : null; })(),
        kids: kids.map(el => ({ id: el.id || el.className || el.tagName,
                                covers: getComputedStyle(el).position === 'absolute',
                                ...rect(el) })),
        controls: controls.map(el => ({ id: el.id || el.tagName, ...rect(el) })),
        stripCtl,
        stopVisible: vis(stop),
        stopText: stop ? stop.textContent.trim() : null,
        stopHitTarget: hitStop,
        stopStyle: stopStyle ? {
          position: stopStyle.position, fontWeight: stopStyle.fontWeight,
          boxShadow: stopStyle.boxShadow, padding: stopStyle.padding,
          borderRadius: stopStyle.borderRadius, opacity: stopStyle.opacity,
          outline: stopStyle.outlineStyle,
          color: stopStyle.color, background: stopStyle.backgroundColor
        } : null,
        stopRect: stop && vis(stop) ? rect(stop) : null,
        label: lab ? (() => {
          /* scrollWidth > clientWidth is the wrong axis for this element.
             #postureLabel is display:block with white-space:normal, so it
             WRAPS rather than overflowing and scrollWidth is identically
             clientWidth — the check could never fire. The ways this label
             actually breaks are vertical: it wraps to more lines than it has
             words, or it is clipped by an ancestor, or a word is sliced.
             smoke.js already had the right technique; this is that technique.

             A label may use as many lines as it has words, and no more. */
          const cs = getComputedStyle(lab);
          let lh = parseFloat(cs.lineHeight);
          if (!lh || isNaN(lh)) lh = parseFloat(cs.fontSize) * 1.2;
          const box = lab.getBoundingClientRect();
          const content = box.height - parseFloat(cs.paddingTop) - parseFloat(cs.paddingBottom);
          const lines = Math.max(1, Math.round(content / lh));
          const words = lab.textContent.trim().split(/\s+/).filter(Boolean);

          // Could every word have fitted on a line of its own?
          const probe = document.createElement('span');
          probe.style.cssText = 'position:absolute;visibility:hidden;white-space:pre;font:' + cs.font;
          document.body.appendChild(probe);
          const room = box.width - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
          const wordsFit = words.every(w => {
            probe.textContent = w;
            return probe.getBoundingClientRect().width <= room + 1;
          });
          probe.remove();

          // Clipped by the label itself, or by anything it sits inside.
          let clippedBy = null;
          for (let el = lab; el && el.id !== 'app'; el = el.parentElement) {
            const es = getComputedStyle(el);
            const r = el.getBoundingClientRect();
            if ((es.overflow === 'hidden' || es.overflowY === 'hidden') &&
                el.scrollHeight > el.clientHeight + 1) { clippedBy = el.id || el.className; break; }
            if (el !== lab && box.bottom > r.bottom + 1 &&
                (es.overflow === 'hidden' || es.overflowY === 'hidden')) {
              clippedBy = el.id || el.className; break;
            }
          }
          /* A word split across two line boxes has more than one client rect.
             This is the direct measurement of "never a partial word" — the
             lines-vs-words heuristic misses word-break:break-all, which slices
             words while producing FEWER lines than the label has words. */
            const sliced = [];
          const tn = lab.firstChild;
          if (tn && tn.nodeType === 3) {
            const re = /\S+/g;
            let m;
            while ((m = re.exec(tn.textContent))) {
              const rg = document.createRange();
              rg.setStart(tn, m.index);
              rg.setEnd(tn, m.index + m[0].length);
              const rects = [].slice.call(rg.getClientRects())
                .filter(q => q.width > 0.5 && q.height > 0.5);
              if (rects.length > 1) sliced.push(m[0]);
            }
          }

          // The label's own box outgrowing the control that holds it.
          const holder = lab.parentElement;
          return {
            text: lab.textContent.trim(),
            lines, words: words.length, wordsFit, sliced,
            clippedBy,
            overflow: cs.textOverflow,
            widthClipped: lab.scrollWidth > lab.clientWidth + 1,
            holderOverflows: holder
              ? holder.scrollHeight > holder.clientHeight + 1 : false,
            holderId: holder ? (holder.id || holder.className) : null,
            heightOverflows: box.bottom > document.getElementById('posture')
              .getBoundingClientRect().bottom + 1
          };
        })() : null,
        docScrollsX: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
        TOUCH_TARGET
      };
    }, { TOUCH_TARGET });

    const g = await geom();

    console.log('\nposture row, worst case (' + label + ')');
    console.log('  in the row:      ' + g.kids.map(k => k.id + ' ' +
                Math.round(k.w) + 'x' + Math.round(k.h)).join(', '));
    console.log('  posture label:   "' + (g.label && g.label.text) + '"' +
                (g.label && g.label.clipped ? ' CLIPPED' : ' fits'));

    // The worst case is only worth measuring if it actually assembled.
    const ids = g.kids.map(k => k.id);
    const wanted = ['sync', 'postureBtn', 'sitEdit', 'stopBtn'];
    const missing = wanted.filter(w => !ids.includes(w));
    if (missing.length) {
      problems.push(label + ': the worst case did not assemble — ' + missing.join(', ') +
                    ' not visible in the posture row. Present: ' + JSON.stringify(ids) +
                    '. Every check below would have passed vacuously.');
      return problems;                       // measuring the easy case proves nothing
    }

    // 1. Hit boxes.
    const small = g.controls.filter(c => c.w < TOUCH_TARGET || c.h < TOUCH_TARGET);
    if (small.length) {
      problems.push(label + ': ' + small.length + ' control(s) in the posture row are under ' +
                    TOUCH_TARGET + 'x' + TOUCH_TARGET + ' CSS px: ' +
                    small.map(c => c.id + ' ' + Math.round(c.w) + 'x' + Math.round(c.h)).join(', '));
    }

    /* 2. Overlap, pairwise, and containment in the row.
     *
     * Run against a given state rather than only the resting one. The armed
     * state is the one A4's own description worries about — "TAP AGAIN TO STOP
     * will not render in a narrow slot" — so measuring only at rest would miss
     * exactly the failure this task exists to prevent. */
    const geometryProblems = (state, when) => {
      const found = [];
      for (let i = 0; i < state.kids.length; i++) {
        for (let j = i + 1; j < state.kids.length; j++) {
          const a = state.kids[i], b = state.kids[j];
          // Two controls stacked on purpose is how the armed state works, so an
          // element that deliberately covers the row is not an overlap defect.
          if (a.covers || b.covers) continue;
          const over = a.x < b.r - 0.5 && b.x < a.r - 0.5 && a.y < b.b - 0.5 && b.y < a.b - 0.5;
          if (over) {
            found.push(label + ' (' + when + '): ' + a.id + ' overlaps ' + b.id +
                       ' in the posture row (' + JSON.stringify(a) + ' vs ' + JSON.stringify(b) + ')');
          }
        }
      }
      const spilling = state.kids.filter(k => k.x < state.postureRect.x - 0.5 ||
                                              k.r > state.postureRect.r + 0.5);
      if (spilling.length) {
        found.push(label + ' (' + when + '): ' + spilling.map(k => k.id).join(', ') +
                   ' extend past the posture row horizontally');
      }
      if (state.docScrollsX) {
        found.push(label + ' (' + when + '): the document scrolls horizontally');
      }
      return found;
    };
    problems.push(...geometryProblems(g, 'resting'));
    /* Hit-tested at rest, not only after the strip. Without this, something
       covering the row is caught only by Playwright's 30s actionability
       timeout, which reports a stack trace and no criterion name. */
    if (g.stopHitTarget !== 'stopBtn') {
      problems.push(label + ': STOP is not hittable in the resting worst case — the element at ' +
                    'its centre is ' + g.stopHitTarget);
    }

    // 3. The posture label is legible or explicitly truncated, never a part-word.
    if (!g.label || !g.label.text) {
      problems.push(label + ': the posture label rendered no text at all');
    } else {
      const L = g.label;
      if (L.widthClipped && L.overflow !== 'ellipsis') {
        problems.push(label + ': the posture label "' + L.text + '" is cut off sideways with ' +
                      'no ellipsis, so it renders a partial word');
      }
      // Measured directly: a word occupying two line boxes has been cut in half.
      if (L.sliced.length && L.wordsFit) {
        problems.push(label + ': the posture label "' + L.text + '" renders ' +
                      L.sliced.length + ' word(s) split across lines (' + L.sliced.join(', ') +
                      ') and every word had room to fit — so a word is being cut in half');
      }
      // More lines than words is the same fault seen from the other side.
      if (L.lines > L.words && L.wordsFit) {
        problems.push(label + ': the posture label "' + L.text + '" is broken across ' + L.lines +
                      ' lines for ' + L.words + ' word(s), and every word had room to fit');
      }
      if (L.holderOverflows) {
        problems.push(label + ': the posture label "' + L.text + '" is taller than the ' +
                      L.holderId + ' that holds it, so it renders outside its own control');
      }
      if (L.clippedBy) {
        problems.push(label + ': the posture label "' + L.text + '" is clipped by ' + L.clippedBy +
                      ', so whole lines of it are not on screen');
      }
      if (L.heightOverflows) {
        problems.push(label + ': the posture label "' + L.text + '" renders past the bottom of ' +
                      'the posture row');
      }
    }

    // 4. Armed differs from resting in text AND in more than colour.
    const resting = { text: g.stopText, style: g.stopStyle, rect: g.stopRect };
    /* Short timeout, and a failure to click is reported as a finding rather
       than thrown. Something covering the row makes Playwright wait 30s and
       then raise a stack trace with no criterion name in it — the hit test
       above has already said what is wrong, and that is the message worth
       showing. */
    const tapStop = async () => {
      try { await pg.click('#stopBtn', { timeout: 2000 }); return true; }
      catch (e) {
        problems.push(label + ': STOP could not be clicked — ' +
                      String((e && e.message) || e).split('\n')[0]);
        return false;
      }
    };
    if (!await tapStop()) return problems;
    await pg.waitForTimeout(30);
    const g2 = await geom();
    const armed = { text: g2.stopText, style: g2.stopStyle, rect: g2.stopRect };
    console.log('  STOP resting:    "' + resting.text + '" ' +
                Math.round(resting.rect.w) + 'x' + Math.round(resting.rect.h) +
                ' ' + resting.style.position);
    console.log('  STOP armed:      "' + armed.text + '" ' +
                Math.round(armed.rect.w) + 'x' + Math.round(armed.rect.h) +
                ' ' + armed.style.position);
    if (armed.text === resting.text) {
      problems.push(label + ': armed STOP reads the same as resting STOP ("' + armed.text + '")');
    }
    /* Compared on properties the text cannot move on its own. Width and height
       are deliberately NOT in here: a longer label makes an auto-width button
       wider all by itself, so measuring the box would just re-detect the text
       change and call it styling. This check is only worth having if it can
       fail while the text still changes. */
    const styleKeys = ['position', 'fontWeight', 'boxShadow', 'padding',
                       'borderRadius', 'opacity', 'outline'];
    const shapeChanged = styleKeys.some(k => armed.style[k] !== resting.style[k]);
    if (!shapeChanged) {
      problems.push(label + ': armed STOP differs from resting only in colour — ' +
                    JSON.stringify(resting.style) + ' vs ' + JSON.stringify(armed.style) +
                    '. Colour alone is one channel, and it is the one some people do not have.');
    }
    if (armed.rect && (armed.rect.w < TOUCH_TARGET || armed.rect.h < TOUCH_TARGET)) {
      problems.push(label + ': armed STOP is under the touch target at ' +
                    Math.round(armed.rect.w) + 'x' + Math.round(armed.rect.h));
    }
    // The armed label is the one that might not fit. Measure it, do not assume.
    problems.push(...geometryProblems(g2, 'armed'));
    if (g2.stopHitTarget !== 'stopBtn') {
      problems.push(label + ': armed STOP is not hittable — the element at its centre is ' +
                    g2.stopHitTarget);
    }

    // 5. Confirm, which ends the day and raises the strip over the row; then a
    //    tap that is not a mark must give the row — and STOP — back.
    if (!await tapStop()) return problems;
    await pg.waitForTimeout(30);
    const g3 = await geom();
    if (g3.stripHidden !== false) {
      problems.push(label + ': ending a 40-minute block with STOP did not raise the mark strip ' +
                    '(strip hidden=' + g3.stripHidden + '), so criterion 5 could not be tested');
    } else {
      await pg.evaluate(() => {
        // Anywhere on the strip that is not one of the three mark buttons.
        document.getElementById('stripHead').click();
      });
      await pg.waitForTimeout(30);
      const g4 = await geom();
      console.log('  strip controls:  ' + (g3.stripCtl.length
        ? g3.stripCtl.map(c => c.id + ' ' + Math.round(c.w) + 'x' + Math.round(c.h)).join(', ')
        : 'none measured'));
      const stripSmall = g3.stripCtl.filter(c => c.w < TOUCH_TARGET || c.h < TOUCH_TARGET);
      if (stripSmall.length) {
        console.log('  NOTE:            ' + stripSmall.map(c => c.id).join(', ') +
                    ' are under ' + TOUCH_TARGET + 'x' + TOUCH_TARGET +
                    '. Pre-existing, outside criterion 1\'s scope, parked as Q8.');
      }
      if (g4.stripHidden !== true) {
        problems.push(label + ': tapping the strip away from a mark did not dismiss it');
      }
      if (!g4.stopVisible) {
        problems.push(label + ': STOP is not visible after the strip is dismissed');
      } else if (g4.stopHitTarget !== 'stopBtn') {
        problems.push(label + ': STOP is visible but not hittable after the strip is dismissed — ' +
                      'the element at its centre is ' + g4.stopHitTarget);
      }
    }

    if (errors.length) problems.push(label + ': page errors — ' + errors.join(' | '));
  } finally {
    await ctx.close();
  }
  return problems;
}

function sameMetas(a, b) {
  const norm = list => list.map(m => m[0] + '\0' + m[1]).sort();
  const x = norm(a), y = norm(b);
  return x.length === y.length && x.every((v, i) => v === y[i]);
}

async function checkViewport(browser, view, page, expectedChecks) {
  const problems = [];
  const r = await renderOnce(browser, view, page, 'before');

  console.log('\n' + view.name + ' (' + view.width + 'x' + view.height + ')');
  console.log('  meta tags:       ' + r.metas.map(m => m[0]).join(', '));
  console.log('  category cells:  ' + r.cells);
  console.log('  smoke checks:    ' + r.smoke.pass + ' passed, ' + r.smoke.fail + ' failed');

  if (r.errors.length) problems.push(view.name + ': the page threw: ' + r.errors.join(' | '));

  if (!sameMetas(r.metas, META_TAGS)) {
    problems.push(view.name + ': the rendered page does not carry the tags this harness ' +
                  'injected.\n    rendered: ' + JSON.stringify(r.metas) +
                  '\n    injected: ' + JSON.stringify(META_TAGS));
  }

  // The runtime twin of the drift rule in test/lint.js. The lint is the one
  // that runs without an install; this catches the same thing while a browser
  // happens to be open, and names which side is missing what.
  if (!sameMetas(META_TAGS, page.metas)) {
    problems.push(view.name + ': doGet and this harness disagree about the meta tags.\n' +
                  '    doGet sends:      ' + JSON.stringify(page.metas) +
                  '\n    harness injects:  ' + JSON.stringify(META_TAGS));
  }

  if (r.cells !== page.categories.length) {
    problems.push(view.name + ': the grid holds ' + r.cells + ' cells but ' +
                  page.categories.length + ' categories are configured — the bootstrap ' +
                  'config or the client script did not survive the render');
  }

  // Zero checks is never a pass. test/README.md records why.
  if (!r.smoke || typeof r.smoke.pass !== 'number' || r.smoke.pass === 0) {
    problems.push(view.name + ': smoke.js reported no passing checks at all, so nothing ' +
                  'was really verified (' + JSON.stringify(r.smoke) + ')');
    return problems;
  }

  // Every check the file declares must be accounted for as passed, failed or
  // explicitly skipped. A check that quietly stopped running would otherwise
  // leave the run green with less behind it than it had yesterday.
  const skipped = r.smoke.skipped || [];
  const total = r.smoke.pass + r.smoke.fail + skipped.length;
  if (total !== expectedChecks) {
    problems.push(view.name + ': smoke.js accounts for ' + total + ' checks but the file ' +
                  'contains ' + expectedChecks + ' — one is neither passing, failing nor skipped');
  }

  if (r.smoke.fail !== 0) {
    problems.push(view.name + ': ' + r.smoke.fail + ' smoke check(s) failed:\n' +
                  (r.smoke.failed || []).map(f => '    - ' + f.name +
                    (f.detail ? ' (' + f.detail + ')' : '')).join('\n'));
  }

  return problems;
}

/**
 * Prove the meta tags are load-bearing rather than decoration. Without the
 * viewport tag Blink lays the page out at its default 980px and scales it down,
 * which is a different document from the one a phone gets.
 *
 * This measures layout width and not the smoke checks, and that is a finding
 * rather than a shortcut: no check in smoke.js is viewport-sensitive. Every one
 * of them is relative — app height against window.innerHeight, cells equal
 * width, rows full — and all of those hold just as well at 980px as at 390px.
 * See F4 in factory/progress.md. It is also concrete evidence for why the phone
 * paste is not superseded by this layer.
 */
async function checkInjectionMatters(browser, view, page) {
  const withMetas = await renderOnce(browser, view, page, 'before');
  const without = await renderOnce(browser, view, page, 'none');
  console.log('\nmeta-tag control');
  console.log('  layout width with the tags:    ' + withMetas.layoutWidth + 'px');
  console.log('  layout width without them:     ' + without.layoutWidth + 'px');
  if (withMetas.layoutWidth === without.layoutWidth) {
    return ['the meta tags changed nothing about how the page laid out, so this run ' +
            'cannot claim to be rendering the document Apps Script serves'];
  }
  if (withMetas.layoutWidth !== view.width) {
    return ['with the meta tags the page laid out at ' + withMetas.layoutWidth +
            'px, not the ' + view.width + 'px viewport it was given'];
  }
  return [];
}

async function main() {
  const { chromium } = loadPlaywright();
  const page = served();
  const expectedChecks = countChecks();
  if (!expectedChecks) fail('Found no checks in test/smoke.js to run.');

  let browser;
  try {
    browser = await chromium.launch();
  } catch (e) {
    fail(['The pinned browser will not launch. Install it with:',
          '',
          '    ' + INSTALL_BROWSER,
          '',
          String((e && e.message) || e)]);
  }

  const VIEWS = [
    { name: 'phone', width: 390, height: 844, isMobile: true },
    { name: 'desktop', width: 1280, height: 800, isMobile: false }
  ];
  let problems = [];
  try {
    for (const view of VIEWS) {
      problems = problems.concat(await checkViewport(browser, view, page, expectedChecks));
    }
    problems = problems.concat(await checkInjectionMatters(browser, VIEWS[0], page));
    problems = problems.concat(await checkDrawer(browser, VIEWS[0], page));
    problems = problems.concat(await checkTapCount(browser, VIEWS[0], page));
    /* A4: the worst-case posture row, on a phone and on a desktop. 980px is
       named in the contract specifically so STOP cannot become a phone-only
       control that nobody checked anywhere else. */
    for (const view of [VIEWS[0], { name: 'desktop', width: 980, height: 800, isMobile: false }]) {
      problems = problems.concat(await checkPostureRow(browser, view, page));
    }
  } finally {
    await browser.close();
  }

  if (problems.length) fail(problems);
  console.log('\nheadless: ok (' + expectedChecks + ' checks per viewport)');
}

main().catch(e => fail(String((e && e.stack) || e)));
