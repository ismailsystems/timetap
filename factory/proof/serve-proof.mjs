/*
 * A static server for the proof video, and nothing else.
 *
 * The recording engine drives a browser by URL, so every scene the video needs
 * has to be reachable as a plain page load. That means the two things
 * test/headless.js does with Playwright hooks — stub the server, seed the dead
 * list — have to be baked into the document instead.
 *
 * Two rules this file exists to keep:
 *
 *   1. NOTHING here talks to Google. `google.script.run` is stubbed before the
 *      client script runs, so no tap in the video can reach a real calendar.
 *      The stub answers every call with an empty, healthy day.
 *   2. The page is the real one. The markup and the client script come from the
 *      real doGet via test/serve.js, with the same three meta tags Apps Script
 *      injects — not Index.html off the disk, which still holds the bootstrap
 *      placeholder. A video of a document the phone never loads would prove
 *      nothing.
 *
 * Every route below is the same real app; they differ only in what is already
 * on the shelf when it boots. Separate routes because the engine only reloads
 * when a beat's page changes, and each scene needs a clean start.
 *
 * Dev-only, never deployed. Run:  node factory/proof/serve-proof.mjs [port]
 */
import { execFileSync } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..', '..');
const PORT = Number(process.argv[2] || 4173);

const META_TAGS = [
  ['viewport', 'width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no'],
  ['apple-mobile-web-app-capable', 'yes'],
  ['mobile-web-app-capable', 'yes']
];
const esc = s => String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');

const page = JSON.parse(execFileSync(process.execPath, [join(ROOT, 'test', 'serve.js')],
                                     { cwd: ROOT, encoding: 'utf8' }));

/* Three set-aside writes, worded the way real ones are: a time, a category, what
   it was trying to do, and the server's own reason. Nothing invented that the
   drawer would not really show. */
const THREE = [
  { at: Date.parse('2026-07-27T09:12:00'), why: 'API call to calendar.events.patch failed with error: Not Found',
    key: 'ADM', startMs: Date.parse('2026-07-27T09:00:00'), op: { id: 'a1', type: 'setMark', ref: 'r1' } },
  { at: Date.parse('2026-07-27T10:41:00'), why: 'API call to calendar.events.patch failed with error: Rate Limit Exceeded',
    key: 'DW',  startMs: Date.parse('2026-07-27T10:05:00'), op: { id: 'b2', type: 'closeActual', ref: 'r2' } },
  { at: Date.parse('2026-07-27T11:58:00'), why: 'API call to calendar.events.insert failed with error: Forbidden',
    key: 'MTG', startMs: Date.parse('2026-07-27T11:50:00'), op: { id: 'c3', type: 'openActual', ref: 'r3' } }
];

/* One entry written by an older version of the app: no category, no start time,
   and an op type the drawer has no wording for. It must render, not crash. */
const LEGACY = [
  { at: Date.parse('2026-07-27T08:30:00'), why: 'API call to calendar.events.patch failed with error: Not Found',
    op: { id: 'old', type: 'setText', ref: 'r9' } }
];

/* `open` means: tap the banner once on load, so the beat starts with the drawer
   already showing.
 *
 * This is scene setup, not a change to the app. The rows are still rendered by
 * the real renderDead, and the tap is the same tap a thumb makes. It exists
 * because the recording engine resolves every selector on a bare page load
 * before it will record, and a row inside a closed drawer does not exist yet.
 * One beat (/drawer) deliberately keeps it closed, because opening it is the
 * thing that beat is there to show. */
const SCENES = {
  '/':             { dead: [],                              open: false },
  '/app':          { dead: [],                              open: false },
  '/drawer':       { dead: THREE,                           open: false },
  '/drawer-open':  { dead: THREE,                           open: true  },
  '/drawer2':      { dead: THREE,                           open: true  },
  '/legacy':       { dead: LEGACY.concat(THREE.slice(0, 2)), open: true  },
  '/last':         { dead: [THREE[2]],                      open: true  }
};

/* Runs before the client script, so the app boots into this world rather than
   discovering it later. */
function preamble(dead, open) {
  return `<script>
(function () {
  try { localStorage.clear(); } catch (e) {}
  localStorage.setItem('tt.dead.v1', ${JSON.stringify(JSON.stringify(dead))});
  // A server that always succeeds with an empty day. It never reaches Google;
  // there is no network call behind any of this.
  var mk = function () {
    var b = {
      withSuccessHandler: function (f) { b._ok = f; return b; },
      withFailureHandler: function (f) { b._fail = f; return b; },
      applyOps: function () { setTimeout(function () { b._ok && b._ok({ applied: [], errors: [], dropped: [] }); }, 5); },
      getState: function () { setTimeout(function () { b._ok && b._ok({ open: null, today: [], sit: null, sitToday: [] }); }, 5); },
      addCategory: function () { setTimeout(function () { b._ok && b._ok({}); }, 5); }
    };
    return b;
  };
  window.google = { script: { run: new Proxy({}, { get: function (_, k) {
    return function () { var b = mk(); return b[k] && b[k].apply(b, arguments); };
  } }) } };
  ${open ? `window.addEventListener('load', function () {
    setTimeout(function () {
      var el = document.getElementById('err');
      if (el) el.click();
    }, 500);
  });` : ''}
})();
</script>`;
}

function documentFor(scene) {
  return '<!doctype html>\n<html>\n<head>\n' +
    META_TAGS.map(m => '  <meta name="' + esc(m[0]) + '" content="' + esc(m[1]) + '">').join('\n') +
    '\n  <title>' + esc(page.title) + '</title>\n' + preamble(scene.dead, scene.open) +
    '\n</head>\n<body>\n' + page.html + '\n</body>\n</html>';
}

createServer((req, res) => {
  const path = (req.url || '/').split('?')[0];
  if (path === '/results') {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    return res.end(readFileSync(join(HERE, 'test-results.html')));
  }
  const scene = SCENES[path];
  if (scene === undefined) { res.writeHead(404); return res.end('no such scene'); }
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  res.end(documentFor(scene));
}).listen(PORT, () => {
  console.log('proof server on http://localhost:' + PORT);
  console.log('scenes: ' + Object.keys(SCENES).concat('/results').join('  '));
});
