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
  } finally {
    await browser.close();
  }

  if (problems.length) fail(problems);
  console.log('\nheadless: ok (' + expectedChecks + ' checks per viewport)');
}

main().catch(e => fail(String((e && e.stack) || e)));
