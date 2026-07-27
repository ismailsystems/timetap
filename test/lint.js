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
const { execFileSync } = require('child_process');

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

/* ── the two meta-tag lists that have to agree ──────────────────────
 *
 * Apps Script ignores meta tags written into the HTML file and injects the ones
 * doGet asks for through addMetaTag. The headless harness has to inject the
 * same list or it renders a document the phone never loads — and it would go on
 * passing while doing it, which is worse than not rendering at all.
 *
 * The lists live in two files on purpose (deriving one from the other makes the
 * comparison self-fulfilling), so this rule is the only thing holding them
 * together. It is the single check that makes rendering locally honest rather
 * than a convenient fiction.
 */
const APPS_SCRIPT_META = ['viewport', 'apple-mobile-web-app-capable',
                          'mobile-web-app-capable', 'google-site-verification'];
const headlessSrc = fs.readFileSync(path.join(__dirname, 'headless.js'), 'utf8');

function metasFromDoGet(src) {
  const out = [], re = /\.addMetaTag\(\s*'([^']*)'\s*,\s*'([^']*)'\s*\)/g;
  let m;
  while ((m = re.exec(src))) out.push([m[1], m[2]]);
  return out;
}
function metasFromHarness(src) {
  const block = /META_TAGS\s*=\s*\[([\s\S]*?)\n\];/.exec(src);
  if (!block) return [];
  const out = [], re = /\[\s*'([^']*)'\s*,\s*'([^']*)'\s*\]/g;
  let m;
  while ((m = re.exec(block[1]))) out.push([m[1], m[2]]);
  return out;
}

const doGetMetas = metasFromDoGet(codeNoComments);
const harnessMetas = metasFromHarness(headlessSrc);

/* Everything below compares two lists. If either parsed as empty, every one of
   those comparisons passes while comparing nothing — the vacuous-assertion bug
   test/README.md:63 records. So an empty list is a failure in its own right. */
check('both meta tag lists were actually found',
  (doGetMetas.length ? [] : ['Code.gs: no addMetaTag calls parsed out of doGet'])
    .concat(harnessMetas.length ? [] : ['test/headless.js: no META_TAGS entries parsed']),
  'an empty list would make every comparison below pass without comparing anything');

/* A repeated name would collapse when the lists are keyed by name, hiding a
   difference behind whichever copy happened to be last. */
const dupes = list => list.map(t => t[0])
  .filter((n, i, a) => a.indexOf(n) !== i)
  .filter((n, i, a) => a.indexOf(n) === i);
check('neither list declares the same meta tag twice',
  dupes(doGetMetas).map(n => 'Code.gs: ' + n)
    .concat(dupes(harnessMetas).map(n => 'test/headless.js: ' + n)),
  'a duplicate name hides a difference behind whichever copy is read last');

const byName = list => new Map(list);
const dg = byName(doGetMetas), hn = byName(harnessMetas);
const drift = [];
dg.forEach(function (content, name) {
  if (!hn.has(name)) {
    drift.push(name + ' — doGet sends it, test/headless.js does not inject it');
  } else if (hn.get(name) !== content) {
    drift.push(name + ' — same tag, different content: doGet has "' + content +
               '", test/headless.js has "' + hn.get(name) + '"');
  }
});
hn.forEach(function (content, name) {
  if (!dg.has(name)) {
    drift.push(name + ' — test/headless.js injects it, doGet does not send it');
  }
});
check('doGet and the headless harness inject the same meta tags', drift,
  'the harness must render the document Apps Script serves, not a near miss');

/* Anything outside the four permitted names throws at request time, which is a
   crash you only ever see on the deployed URL. */
check('every meta tag name is one Apps Script permits',
  doGetMetas.map(t => t[0]).filter(n => APPS_SCRIPT_META.indexOf(n) < 0)
    .map(n => 'Code.gs: ' + n)
    .concat(harnessMetas.map(t => t[0]).filter(n => APPS_SCRIPT_META.indexOf(n) < 0)
      .map(n => 'test/headless.js: ' + n)),
  'addMetaTag throws "not allowed in this context" at request time for any other name');

/* A stray NUL byte makes git classify the file as binary: `git diff` prints
   "Binary files differ" and shows nothing, and `git grep` skips it. test/headless.js
   shipped with one — a separator written as the byte itself rather than as '\0' —
   so the whole headless runner was unreviewable for a round. Contract 26.

   Assertion 26 says "any file in the repo", so the list is the repo's own, not one
   typed out here. A hand-written list was the first version of this rule and it
   already had holes: factory/, site/, .github/ and test/fixtures/ were all outside
   it, and a NUL appended to factory/log.md passed lint clean. A list that has to be
   edited when a directory is added is a list that goes stale the first time nobody
   remembers to edit it. */

/**
 * Every file in the repo, and how we worked that out.
 *
 * `--others --exclude-standard` puts untracked-but-not-ignored files in too, so a
 * doc dropped in and not yet `git add`ed is still covered. A rule that only saw
 * committed files would give a new file a free pass for exactly as long as it took
 * someone to notice — which is the same hole the hand-written list had.
 */
function repoFiles() {
  if (fs.existsSync(path.join(ROOT, '.git'))) {
    try {
      const out = execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'],
                               { cwd: ROOT, encoding: 'utf8' });
      return { how: 'git ls-files', files: out.split('\0').filter(Boolean) };
    } catch (e) { /* fall through to the walk */ }
  }
  /* A checkout with no git directory — an export, a tarball, a fixture copy — still
     has to be lintable, so the rule walks instead. Same rule, different census: the
     walk cannot ask what is tracked, so it skips the three things that are never
     tracked here. `.clasp.json` is gitignored, machine-specific and holds a script
     id; standing in for the tracked list means not reading it. */
  const files = [];
  (function walk(dir) {
    for (const name of fs.readdirSync(dir).sort()) {
      if (name === '.git' || name === 'node_modules' || name === '.clasp.json') continue;
      const full = path.join(dir, name);
      if (fs.statSync(full).isDirectory()) walk(full);
      else files.push(path.relative(ROOT, full));
    }
  })(ROOT);
  return { how: 'no git directory — walked the tree', files: files };
}

/* Tracked files that are genuinely binary and so cannot be reviewed as text.
   Empty on purpose: there are none today. Putting a file here is a decision to
   accept something nobody can diff, so it is named one line at a time with the
   reason — never widened into an extension filter, which would silently swallow
   the next Code.gs that grew a NUL. */
const BINARY_EXEMPT = [];

const census = repoFiles();
const nulBad = [], nulSkipped = [];
for (const rel of census.files) {
  const full = path.join(ROOT, rel);
  let buf;
  try {
    if (!fs.existsSync(full)) continue;          // tracked but deleted in the worktree
    /* Not everything git lists is a file to read. `.gitignore` says `node_modules/`,
       which matches a directory and not a symlink pointing at one, so a checkout
       that symlinks its node_modules gets the whole tree offered here. Nothing that
       is not a regular file can hold a NUL of its own — git stores a symlink as its
       target path — so these are skipped, out loud. */
    if (!fs.statSync(full).isFile()) {
      nulSkipped.push(rel + ' — not a regular file, so there is no text to read');
      continue;
    }
    buf = fs.readFileSync(full);
  } catch (e) {
    nulBad.push(rel + ' — could not be read at all: ' + ((e && e.message) || e));
    continue;
  }
  if (!buf.includes(0)) continue;
  if (BINARY_EXEMPT.indexOf(rel) >= 0) {
    nulSkipped.push(rel + ' — exempt: declared binary in test/lint.js');
  } else {
    nulBad.push(rel + ' — contains a NUL byte, so git classifies it as binary');
  }
}
check('no file in the repo contains a NUL byte', nulBad,
  'git treats a file with a NUL as binary, so its diffs become invisible to review');
/* Which files were looked at, and which were not, said out loud — a rule that
   quietly scanned nothing would print the same "ok" as one that scanned the repo. */
console.log('         ' + census.files.length + ' files scanned (' + census.how + ')');
nulSkipped.forEach(function (s) { console.log('         skipped ' + s); });

/* The manifest asked for three OAuth scopes while README claimed one, for long
   enough that the claim was copied into a build contract as fact. A count in prose
   drifts silently; this makes it drift loudly. Contract 27.

   Assertion 27 says "no sentence anywhere", so the rule reads every .md in the
   repo, not the two it used to. Reading only README.md and SETUP.md left
   factory/BRIEF.md and factory/PLAN.md still saying "one OAuth scope" and passing —
   and BRIEF's orientation table stated it as a current fact about the repo, which
   is precisely how the wrong number got quoted into a build contract in the first
   place. */
const SCOPE_COUNT = (JSON.parse(manifest).oauthScopes || []).length;
const NUMBER_WORDS = ['zero', 'one', 'two', 'three', 'four', 'five', 'six'];

/* Files that quote the old, wrong sentence deliberately: they are the record of
   what was wrong and when, and correcting them would destroy the evidence. Named
   one at a time with the reason, never a pattern — a pattern over `factory/` or
   over "anything mentioning REVIEW" would quietly swallow a doc that is genuinely
   stating a current fact, which is the failure mode this rule exists to catch.

   HANDOFF.md is here for a second reason as well: amendment A2 quotes the original
   contract sentence verbatim, and the file is under a never-edit guardrail. That
   makes this entry the weakest one in the list — a wrong count introduced anywhere
   else in HANDOFF.md would not be caught. It is named here so the next reviewer
   sees the gap rather than discovering it. */
const SCOPE_QUOTE_EXEMPT = {
  'factory/REVIEW.md':    'review 1 — quotes README\'s wrong sentence as the finding',
  'factory/REVIEW-2.md':  'review 2 — quotes BRIEF\'s and PLAN\'s wrong sentences as the finding',
  'factory/FIXES.md':     'fix list 1 — quotes the wrong sentence in the task that fixed it',
  'factory/FIXES-2.md':   'fix list 2 — quotes the wrong sentences in the task that fixed them',
  'factory/log.md':       'append-only build log — records the finding in its own words',
  'factory/progress.md':  'append-only progress record — records the finding in its own words',
  'factory/STATE.md':     'factory state — summarises the finding for the next stage',
  'factory/HANDOFF.md':   'contract amendment A2 quotes the original wrong sentence; also never-edit'
};

const scopeDocs = census.files.filter(f => /\.md$/i.test(f)).sort();
const scopeBad = [];
for (const rel of scopeDocs) {
  if (SCOPE_QUOTE_EXEMPT[rel]) continue;
  const full = path.join(ROOT, rel);
  if (!fs.existsSync(full)) continue;
  const text = fs.readFileSync(full, 'utf8');
  const re = /\b(zero|one|two|three|four|five|six|\d+)\s+(?:OAuth\s+)?scopes?\b/gi;
  let m;
  while ((m = re.exec(text))) {
    const said = /^\d+$/.test(m[1]) ? Number(m[1]) : NUMBER_WORDS.indexOf(m[1].toLowerCase());
    if (said !== SCOPE_COUNT) {
      const line = text.slice(0, m.index).split('\n').length;
      scopeBad.push(rel + ':' + line + ' — "' + m[0] + '" but appsscript.json asks for ' + SCOPE_COUNT);
    }
  }
}
check('the docs agree with the manifest about how many scopes it asks for', scopeBad,
  'a scope count stated in prose goes stale silently, and then gets quoted as fact');
console.log('         ' + (scopeDocs.length - Object.keys(SCOPE_QUOTE_EXEMPT).length) +
            ' of ' + scopeDocs.length + ' .md files checked; ' +
            Object.keys(SCOPE_QUOTE_EXEMPT).length + ' exempt as the record of the mistake');

console.log(fails ? '\n' + fails + ' failed\n' : '\nall clear\n');
process.exit(fails ? 1 : 0);
