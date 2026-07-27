#!/usr/bin/env node
/*
 * The layer that has seen a pixel, without a human holding a phone.
 *
 * It renders what doGet serves in a real browser engine and reports facts read
 * back out of the live DOM. It does not replace test/smoke.js on the phone:
 * two of the three bug classes smoke.js exists for have only ever appeared on
 * real hardware, and this cannot see those.
 *
 * Dev-only. Nothing here is deployed; the four source files import nothing.
 */
const { execFileSync } = require('child_process');
const path = require('path');

const ROOT = path.join(__dirname, '..');
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

async function launch(chromium) {
  try {
    return await chromium.launch();
  } catch (e) {
    fail(['The pinned browser will not launch. Install it with:',
          '',
          '    ' + INSTALL_BROWSER,
          '',
          String((e && e.message) || e)]);
  }
}

async function main() {
  const { chromium } = loadPlaywright();
  const page = served();
  const browser = await launch(chromium);
  let problems = [];

  try {
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
    const pg = await ctx.newPage();
    const errors = [];
    pg.on('pageerror', e => errors.push(String((e && e.message) || e)));

    await pg.setContent(page.html, { waitUntil: 'load' });

    const cells = await pg.locator('#grid [data-key]').count();
    console.log('category cells rendered: ' + cells);

    if (errors.length) problems.push('the page threw: ' + errors.join(' | '));
    if (cells === 0) {
      problems.push('the grid rendered no category cells, so nothing was really checked');
    } else if (cells !== page.categories.length) {
      problems.push('the grid holds ' + cells + ' cells but ' + page.categories.length +
                    ' categories are configured (' + page.categories.join(', ') + ')');
    }
  } finally {
    await browser.close();
  }

  if (problems.length) fail(problems);
  console.log('headless: ok');
}

main().catch(e => fail(String((e && e.stack) || e)));
