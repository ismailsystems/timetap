/**
 * Static checks over Index.html and Code.gs.
 *
 * Every rule here exists because a bug of exactly that shape shipped. The
 * behaviour suite could not have caught any of them: they are properties of the
 * source, not of what the source does when it runs.
 *
 *   node test/lint.js
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(ROOT, 'Index.html'), 'utf8');
const code = fs.readFileSync(path.join(ROOT, 'Code.gs'), 'utf8');
const script = html.match(/<script>([\s\S]*)<\/script>/)[1];
const markup = html.replace(/<script>[\s\S]*<\/script>/, '').replace(/<style>[\s\S]*?<\/style>/, '');
const style = (html.match(/<style>([\s\S]*?)<\/style>/) || ['', ''])[1];

/** Comments explain the rules; they must not be mistaken for breaking them. */
function stripComments(js) {
  return js.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/(^|[^:])\/\/[^\n]*/g, '$1 ');
}
/** Only what ends up in a title or a calendar id matters for the ASCII rule. */
function stringLiterals(js) {
  return (stripComments(js).match(/'[^'\n]*'|"[^"\n]*"/g) || []);
}
const codeNoComments = stripComments(code);

let fails = 0;
function check(name, bad, why) {
  const list = Array.isArray(bad) ? bad : (bad ? [bad] : []);
  if (list.length === 0) { console.log('  ok   ' + name); return; }
  fails++;
  console.log('  FAIL ' + name);
  console.log('         ' + why);
  list.slice(0, 8).forEach(function (b) { console.log('         - ' + b); });
}

console.log('\nstatic checks');

/* A handler wired to an element that no longer exists. Shipped twice, both
   times as a blank screen: getElementById returns null and the next property
   access throws before anything renders. */
const declaredIds = new Set((markup.match(/id="([A-Za-z0-9_-]+)"/g) || [])
  .map(function (m) { return m.slice(4, -1); }));
const usedIds = new Set();
(script.match(/\$\('([A-Za-z0-9_-]+)'\)/g) || [])
  .forEach(function (m) { usedIds.add(m.slice(3, -2)); });
(script.match(/getElementById\('([A-Za-z0-9_-]+)'\)/g) || [])
  .forEach(function (m) { usedIds.add(m.slice(15, -2)); });
check('every id the script asks for is declared in the markup',
  [...usedIds].filter(function (id) { return !declaredIds.has(id); }),
  'getElementById returns null for these, and the next property access throws');

/* The same, from the stylesheet: a rule targeting an id that is gone is dead
   weight that reads as if it were still doing something. */
check('every id the stylesheet targets is declared in the markup',
  [...new Set((style.match(/#([A-Za-z0-9_-]+)/g) || [])
    .map(function (m) { return m.slice(1); }))]
    .filter(function (id) { return !declaredIds.has(id) && !/^[0-9a-fA-F]{3,8}$/.test(id); }),
  'these selectors can never match');

/* var() with no definition computes to the initial value rather than falling
   back, so a typo silently turns a colour transparent. */
const defined = new Set((style.match(/--[a-z-]+\s*:/g) || [])
  .map(function (m) { return m.replace(/\s*:$/, '').trim(); }));
check('every custom property used is defined',
  [...new Set((style.match(/var\((--[a-z-]+)/g) || [])
    .map(function (m) { return m.slice(4); }))]
    .filter(function (v) { return !defined.has(v); }),
  'an undefined var() computes to the initial value, not to a fallback');

/* The app was taller than the screen for fourteen deploys because these two
   were written in the order that makes the fallback win. */
check('100dvh comes after 100vh, not before',
  /100dvh\s*;\s*height\s*:\s*100vh/.test(style)
    ? ['height: 100dvh; height: 100vh']
    : [],
  'the later declaration wins, so dvh must be second or vh takes over on iOS');

/* <button> may not contain interactive content. The parser drops it, so a
   querySelector for it returns null and the builder throws. */
const buttonBlocks = markup.match(/<button[\s\S]*?<\/button>/g) || [];
check('no interactive content inside a button in the markup',
  buttonBlocks.filter(function (b) { return /<(input|select|textarea|button|a)\b/i.test(b.slice(7)); })
    .map(function (b) { return b.slice(0, 60).replace(/\s+/g, ' '); }),
  'the parser drops it, so the element is never there to find');

/* Same rule, for the markup the script builds at runtime. */
const built = script.match(/innerHTML\s*=\s*(['"`])([\s\S]*?)\1/g) || [];
check('no interactive content in a template assigned to a button',
  built.filter(function (t) {
    return /<(input|select|textarea)\b/i.test(t) &&
      new RegExp("createElement\\('button'\\)[\\s\\S]{0,400}" +
        t.slice(0, 20).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).test(script);
  }).map(function (t) { return t.slice(0, 60); }),
  'createElement("button") plus an <input> in its innerHTML is the same trap');

/* Marks are parsed off the end of a title by an exact ASCII match. */
check('marks in Code.gs are ASCII only',
  stringLiterals(code).filter(function (lit) { return /[\u2010-\u2015\u2212]/.test(lit); }),
  'parseTitle_ matches +, = and - literally; a dash lookalike silently stops parsing');

/* PLAN is read-only. Nothing in the file may hold a writable handle to it. */
check('no writable handle to the PLAN calendar',
  /function\s+calPlan_|openCal_\(\s*'CAL_PLAN'/.test(codeNoComments)
    ? ['a PLAN calendar handle exists'] : [],
  'PLAN is read through readCal_ only, so no code path can write to it');

/* The repo has dev tooling now, and the four source files still must not. Apps
   Script has no module loader and no build step: an import or a CDN URL in any
   of them is a blank screen on the phone, not a build error anyone would see. */
const manifest = fs.readFileSync(path.join(ROOT, 'appsscript.json'), 'utf8');
const SOURCES = { 'Code.gs': code, 'Index.html': html, 'appsscript.json': manifest };
check('the source files pull nothing in',
  Object.keys(SOURCES).filter(function (name) {
    const body = name === 'Code.gs' ? codeNoComments
               : name === 'Index.html' ? stripComments(script) + markup + style
               : SOURCES[name];
    return /\brequire\s*\(|^\s*import\s|\bfrom\s+['"][^'"]+['"]\s*;|<script[^>]+\bsrc=|https?:\/\/(cdn|unpkg|jsdelivr)/mi.test(body);
  }),
  'no import, require or CDN URL: Apps Script has no module loader and no build step');

/* The browser is tooling, not a dependency of the app. If it ever moves to
   dependencies it ships with nothing that can use it. */
let pkg = null;
try { pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8')); } catch (e) {}
check('the headless browser is a dev dependency',
  !pkg ? ['package.json is missing or unreadable']
       : (pkg.dependencies && Object.keys(pkg.dependencies).length
            ? ['runtime dependencies: ' + Object.keys(pkg.dependencies).join(', ')]
            : (pkg.devDependencies && pkg.devDependencies.playwright ? [] : ['playwright is not in devDependencies'])),
  'nothing in this repo is deployed with the app, so nothing belongs in dependencies');

/* A caret would let the browser move under a pinned expectation, which is the
   one thing the tier-4 canary cannot tell apart from a real break. */
check('the browser version is pinned exactly',
  (pkg && pkg.devDependencies && pkg.devDependencies.playwright &&
   !/^\d+\.\d+\.\d+$/.test(pkg.devDependencies.playwright))
    ? ['playwright: ' + pkg.devDependencies.playwright] : [],
  'an exact version, so "the pinned browser still launches" means something');

console.log(fails ? '\n' + fails + ' failed\n' : '\nall clear\n');
process.exit(fails ? 1 : 0);
