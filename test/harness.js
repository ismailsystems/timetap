/* Minimal Apps Script + DOM shim so the real Code.gs and Index.html run in node. */
const fs = require('fs');
const vm = require('vm');
const path = require('path');

/* ── virtual clock ─────────────────────────────────────────────── */
let NOW = new Date(2026, 6, 20, 9, 0, 0, 0).getTime();   // Mon 20 Jul 2026 09:00 local
let timers = [], tid = 1;
const realNow = Date.now;
Date.now = () => NOW;
global.setTimeout = (fn, ms) => { const t = { id: tid++, at: NOW + (ms || 0), fn, iv: 0 }; timers.push(t); return t.id; };
global.setInterval = (fn, ms) => { const t = { id: tid++, at: NOW + ms, fn, iv: ms }; timers.push(t); return t.id; };
global.clearTimeout = id => { timers = timers.filter(t => t.id !== id); };
global.clearInterval = global.clearTimeout;
function advance(ms) {
  const target = NOW + ms;
  for (;;) {
    const due = timers.filter(t => t.at <= target).sort((a, b) => a.at - b.at);
    if (!due.length) break;
    const t = due[0];
    NOW = t.at;
    if (t.iv) t.at = NOW + t.iv; else timers = timers.filter(x => x !== t);
    t.fn();
  }
  NOW = target;
}
// Advance as little as possible: every settle() adds to a drift that assertions
// then have to tolerate, and a wide tolerance is a place a real error can hide.
function settle() { advance(0); advance(12); }

/* ── fake calendar ─────────────────────────────────────────────── */
class FEvent {
  constructor(cal, title, s, e, d) { this.cal = cal; this.t = title; this.s = +s; this.e = +e; this.d = d || ''; this.c = null; }
  getTitle() { return this.t; }
  setTitle(v) { this.t = v; return this; }
  getStartTime() { return new Date(this.s); }
  getEndTime() { return new Date(this.e); }
  setTime(s, e) { this.s = +s; this.e = +e; return this; }
  getDescription() { return this.d; }
  setDescription(v) { this.d = v; return this; }
  setColor(v) { this.c = v; return this; }
  isAllDayEvent() { return false; }
  deleteEvent() { this.cal.events = this.cal.events.filter(x => x !== this); }
}
class FCal {
  constructor(id) { this.id = id; this.events = []; }
  createEvent(title, s, e, opts) {
    const ev = new FEvent(this, title, s, e, (opts && opts.description) || '');
    this.events.push(ev); return ev;
  }
  getEvents(s, e) {
    return this.events.filter(v => v.e > +s && v.s < +e).sort((a, b) => a.s - b.s);
  }
}
const CALS = { plan: new FCal('plan'), actual: new FCal('actual'), sit: new FCal('sit'),
               alt: new FCal('alt') };

global.CalendarApp = {
  EventColor: { PALE_BLUE:'1', PALE_GREEN:'2', MAUVE:'3', PALE_RED:'4', YELLOW:'5', ORANGE:'6', CYAN:'7', GRAY:'8', BLUE:'9', GREEN:'10', RED:'11' },
  getCalendarById: id => CALS[id] || null
};
global.Session = { getScriptTimeZone: () => process.env.TZ || 'America/New_York' };
const LOGGED = [];
global.Logger = { log: m => { LOGGED.push(String(m)); } };
global.LockService = { getUserLock: () => ({ waitLock() {}, releaseLock() {} }) };
const SCRIPT_PROPS = {};
global.PropertiesService = {
  getScriptProperties: () => ({
    getProperties: () => Object.assign({}, SCRIPT_PROPS),
    getProperty: k => (k in SCRIPT_PROPS ? SCRIPT_PROPS[k] : null),
    setProperty: (k, v) => { SCRIPT_PROPS[k] = String(v); },
    deleteProperty: k => { delete SCRIPT_PROPS[k]; }
  })
};
let uuidN = 0;
global.Utilities = {
  getUuid: () => 'uuid' + (++uuidN).toString(16).padStart(8, '0') + '-0000-0000-0000-000000000000',
  formatDate: (d, tz, fmt) => {
    const p = n => String(n).padStart(2, '0');
    if (fmt === 'yyyy-MM-dd') return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
    throw new Error('unsupported format ' + fmt);
  }
};
const SRC = path.join(__dirname, '..') + '/';

// Apps Script accepts exactly these four names through addMetaTag; anything
// else throws at request time, which is a deploy-only failure unless modelled.
const META_ALLOWED = new Set(['viewport', 'apple-mobile-web-app-capable',
                              'mobile-web-app-capable', 'google-site-verification']);
class FHtmlOutput {
  constructor(content) { this.content = content; this.metas = []; this.title = null; this.xframe = null; }
  setTitle(t) { this.title = t; return this; }
  addMetaTag(n, c) {
    if (!META_ALLOWED.has(n)) throw new Error('The meta tag you specified is not allowed in this context.');
    this.metas.push([n, c]); return this;
  }
  setXFrameOptionsMode(m) { this.xframe = m; return this; }
  getContent() { return this.content; }
}
class FSheet {
  constructor(name) { this.name = name; this.rows = []; this.frozen = 0; }
  getName() { return this.name; }
  clear() { this.rows = []; return this; }
  setFrozenRows(n) { this.frozen = n; return this; }
  getRange(r, c, nr, nc) {
    const sh = this;
    return { setValues(v) { sh.rows = v.map(x => x.slice()); return this; } };
  }
}
class FSpreadsheet {
  constructor(id) { this.id = id; this.sheets = []; }
  getName() { return 'timetap rollup'; }
  getSheets() { return this.sheets.slice(); }
  getUrl() { return 'https://docs.google.com/spreadsheets/d/' + this.id + '/edit'; }
  getSheetByName(n) { return this.sheets.find(s => s.name === n) || null; }
  insertSheet(n) { const s = new FSheet(n); this.sheets.push(s); return s; }
}
const SHEETS = { book: new FSpreadsheet('book') };
global.SpreadsheetApp = {
  openById: id => SHEETS[id] || (() => { throw new Error('no spreadsheet ' + id); })()
};

const TRIGGERS = [];
global.ScriptApp = {
  newTrigger: fn => {
    const t = { fn, hour: null, days: null };
    const b = {
      timeBased: () => b,
      atHour: h => { t.hour = h; return b; },
      everyDays: d => { t.days = d; return b; },
      create: () => { TRIGGERS.push(t); return t; }
    };
    return b;
  },
  getProjectTriggers: () => TRIGGERS.map(t => ({
    getHandlerFunction: () => t.fn, _t: t
  })),
  deleteTrigger: h => { const i = TRIGGERS.indexOf(h._t); if (i >= 0) TRIGGERS.splice(i, 1); }
};

global.HtmlService = {
  XFrameOptionsMode: { ALLOWALL: 'ALLOWALL', DEFAULT: 'DEFAULT', ALLOWSAMEORIGIN: 'ALLOWSAMEORIGIN' },
  createTemplateFromFile: name => {
    const raw = fs.readFileSync(SRC + name + '.html', 'utf8');
    const tpl = {
      evaluate() {
        return new FHtmlOutput(raw.replace(/<\?!?=\s*(\w+)\s*\?>/g, (_, k) => String(tpl[k])));
      }
    };
    return tpl;
  }
};

/* ── load server ───────────────────────────────────────────────── */
let code = fs.readFileSync(SRC + 'Code.gs', 'utf8')
  .replace("var CAL_PLAN    = '';", "var CAL_PLAN    = 'plan';")
  .replace("var CAL_ACTUAL  = '';", "var CAL_ACTUAL  = 'actual';")
  .replace("var CAL_SITTING = '';", "var CAL_SITTING = 'sit';");
vm.runInThisContext(code, { filename: 'Code.gs' });

/* A server rejection and a dropped connection are different failures, and the
 * client is deliberately built to tell them apart. A rejection comes back
 * through the *success* handler as a non-empty errors array (Code.gs:629) and
 * counts against the op's try count; setOnline(false) fires the failure handler
 * and does not count, because retrying is exactly what a network failure wants
 * (Index.html:497). Only the first path can ever set a write aside, and nothing
 * in the shim could reach it, so it gets a switch of its own. Wrapping applyOp_
 * rather than applyOps keeps the real errors/applied/dropped bookkeeping and the
 * real stop-at-first-failure ordering in play. */
const realApplyOp_ = global.applyOp_;
let REJECT = null;
global.applyOp_ = function () {
  if (REJECT !== null) throw new Error(REJECT);
  return realApplyOp_.apply(this, arguments);
};

/* ── DOM shim ──────────────────────────────────────────────────── */
class El {
  constructor(tag) {
    this.tag = tag; this.children = []; this._h = {}; this.dataset = {};
    this.style = { _p: {},
      setProperty(k, v) { this._p[k] = v; },
      getPropertyValue(k) { return this._p[k] || ''; },
      removeProperty(k) { delete this._p[k]; } };
    this._text = ''; this._html = ''; this._stubs = {}; this.value = ''; this.disabled = false;
    this._cls = new Set();
    const self = this;
    this.classList = {
      add: (...c) => c.forEach(x => self._cls.add(x)),
      remove: (...c) => c.forEach(x => self._cls.delete(x)),
      contains: c => self._cls.has(c),
      toggle: (c, on) => { const v = on === undefined ? !self._cls.has(c) : !!on; v ? self._cls.add(c) : self._cls.delete(c); return v; }
    };
    Object.defineProperty(this, 'className', {
      get: () => [...self._cls].join(' '),
      set: v => { self._cls = new Set(String(v).split(/\s+/).filter(Boolean)); }
    });
    Object.defineProperty(this, 'textContent', { get: () => self._text, set: v => { self._text = String(v); } });
    Object.defineProperty(this, 'innerHTML', { get: () => self._html, set: v => { self._html = String(v); self.children = []; self._stubs = {}; } });
  }
  setAttribute(k, v) { this._attrs = this._attrs || {}; this._attrs[k] = String(v); }
  getAttribute(k) { return (this._attrs || {})[k] ?? null; }
  focus() { global.document.activeElement = this; }
  blur() { if (global.document.activeElement === this) global.document.activeElement = null; }
  addEventListener(t, fn) { (this._h[t] = this._h[t] || []).push(fn); }
  fire(t, ev) { (this._h[t] || []).forEach(f => f(ev || { target: this })); }
  click() { this.fire('click', { target: this }); }
  querySelector(sel) {
    // Mirror two things the real parser does, because the shim otherwise hands
    // back a stub for any selector and hides genuine markup bugs:
    //   1. a selector that never appears in the markup matches nothing
    //   2. <button> may not contain interactive content, so an <input> written
    //      into one is dropped rather than parsed
    const cls = sel.replace(/^\./, '');
    if (this._html && this._html.indexOf('class="' + cls) < 0) return null;
    if (this.tag === 'button' && /<(input|button|select|textarea|a)\b/i.test(this._html)) return null;
    return this._stubs[sel] || (this._stubs[sel] = new El('span'));
  }
  appendChild(c) { this.children.push(c); return c; }
  get hidden() { return this._cls.has('hidden'); }
}
const NODES = {};
const INIT_CLS = { strip:'hidden', err:'hidden', week:'hidden', sheetSplit:'hidden',
                   sheetSit:'hidden', sitAdj:'hidden', nowbar:'idle', sync:'s-synced' };
function mkNode(id) {
  const e = new El('div');
  if (INIT_CLS[id]) e.className = INIT_CLS[id];
  // The shim does not parse markup, so anything the HTML declares statically
  // has to be mirrored here. #posture is three buttons the client never builds.
  return e;
}
// Only ids the markup actually declares may resolve. The shim used to invent a
// node for anything asked of it, which hid two real bugs: a handler wired to an
// element that had been deleted, and a selector the parser had dropped. In a
// browser those are null and throw on the next property access.
const MARKUP_IDS = new Set(
  (fs.readFileSync(SRC + 'Index.html', 'utf8').match(/id="([A-Za-z0-9_-]+)"/g) || [])
    .map(m => m.slice(4, -1))
);
const VIS = [];
global.document = {
  getElementById: id => {
    if (!MARKUP_IDS.has(id)) return null;
    return NODES[id] || (NODES[id] = mkNode(id));
  },
  createElement: t => new El(t),
  addEventListener(t, fn) { if (t === 'visibilitychange') VIS.push(fn); },
  hidden: false,
  activeElement: null
};
global.window = { addEventListener() {} };
const STORE = {};
global.localStorage = {
  getItem: k => (k in STORE ? STORE[k] : null),
  setItem: (k, v) => { STORE[k] = String(v); },
  removeItem: k => { delete STORE[k]; }
};
global.navigator = { onLine: true };

let ONLINE = true;
const CALLS = [];
global.google = {
  script: {
    run: (() => {
      function mk() {
        const b = { _ok: null, _fail: null };
        b.withSuccessHandler = f => { b._ok = f; return b; };
        b.withFailureHandler = f => { b._fail = f; return b; };
        ['applyOps', 'getState', 'addCategory'].forEach(name => {
          b[name] = (...args) => {
            CALLS.push(name);
            setTimeout(() => {
              if (!ONLINE) return b._fail && b._fail(new Error('offline'));
              let r;
              try { r = global[name](...args); } catch (e) { return b._fail && b._fail(e); }
              b._ok && b._ok(r);
            }, 5);
          };
        });
        return b;
      }
      const proxy = {};
      ['withSuccessHandler', 'withFailureHandler', 'applyOps', 'getState', 'addCategory']
        .forEach(n => { proxy[n] = (...a) => mk()[n](...a); });
      return proxy;
    })()
  }
};

/* ── load client ───────────────────────────────────────────────── */
const html = fs.readFileSync(SRC + 'Index.html', 'utf8');
const rawScript = html.match(/<script>([\s\S]*)<\/script>/)[1];
// doGet calls clientConfig_() on every page load, so a reboot has to as well —
// otherwise a category added at runtime never reaches a reloaded client.
const script = () => rawScript.replace('<?!= bootstrap ?>', JSON.stringify(clientConfig_()));
vm.runInThisContext(script(), { filename: 'Index.html' });

/* ── test helpers ──────────────────────────────────────────────── */
const $ = id => NODES[id];
const tap = key => { $('grid').children.find(b => b.dataset.key === key).fire('click'); settle(); };
const litPosture = () => ($('postureBtn')._cls.has('on') ? 'sit' : 'stand');
// One button now, so setting a posture means toggling only when it differs.
const posture = k => {
  if (litPosture() !== k) { $('postureBtn').fire('click'); settle(); }
};
const tapSit = () => posture('sit');
const noteBox = () => {
  const b = $('grid').children.find(c => c._cls.has('active'));
  return b ? b.querySelector('.gn') : null;
};
const elapsedBox = () => {
  const b = $('grid').children.find(c => c._cls.has('active'));
  return b ? b.querySelector('.ge').textContent : '';
};
const addCell = () => $('grid').children.find(c => c.dataset.add === '1') || null;
const activeKey = () => {
  const b = $('grid').children.find(c => c._cls.has('active'));
  return b ? b.dataset.key : null;
};

const tapMark = m => { $('strip').fire('click', { target: { closest: () => ({ dataset: { mark: m } }) } }); settle(); };
const wait = min => { advance(min * 60000); settle(); };
const A = () => CALS.actual.events.slice().sort((a, b) => a.s - b.s);
const S = () => CALS.sit.events.slice().sort((a, b) => a.s - b.s);
const desc = e => e.d.replace(/\n/g, '|');
const hhmm = ms => new Date(ms).toTimeString().slice(0, 5);
const show = e => `"${e.t}" ${hhmm(e.s)}-${hhmm(e.e)}${/#open/.test(e.d) ? ' OPEN' : ''}`;

// settle() advances 12ms, so drift across a test is tens of milliseconds, not
// seconds. The tolerance is for that bookkeeping and nothing else.
const near = (a, b, tol) => Math.abs(a - b) <= (tol === undefined ? 750 : tol);
let pass = 0, fail = 0;
function chk(label, cond, detail) {
  if (cond) { pass++; console.log('  ok   ' + label); }
  else { fail++; console.log('  FAIL ' + label + (detail ? '\n         ' + detail : '')); }
}
function reset(atMs) {
  CALS.plan.events = []; CALS.actual.events = []; CALS.sit.events = []; CALS.alt.events = [];
  Object.keys(STORE).forEach(k => delete STORE[k]);
  NOW = atMs !== undefined ? atMs : new Date(2026, 6, 20, 9, 0, 0, 0).getTime();
  ONLINE = true;
  REJECT = null;
  LOGGED.length = 0;
  global.PROPS_ = null;
  SHEETS.book.sheets = [];
  TRIGGERS.length = 0;
  Object.keys(SCRIPT_PROPS).forEach(k => delete SCRIPT_PROPS[k]);
}
function reboot() {
  timers = timers.filter(t => !t.iv);          // drop the tick interval from the old instance
  Object.keys(NODES).forEach(k => delete NODES[k]);
  vm.runInThisContext(script(), { filename: 'Index.html' });
  settle();
}

module.exports = { LOGGED, fireVisible: () => VIS.forEach(f => f()), chk, near, reset, reboot, META_ALLOWED, SCRIPT_PROPS, SHEETS, TRIGGERS,
  posture, activeKey, litPosture, noteBox, elapsedBox, addCell,
  clearPropCache: () => { global.PROPS_ = null; }, tap, tapSit, tapMark, wait, advance, settle, A, S, show, hhmm, $,
  CALS, NODES, STORE, desc,
  get pass() { return pass; }, get fail() { return fail; },
  setOnline: v => { ONLINE = v; },
  // Pass a message to make every server call reject with it; pass null to stop.
  setServerReject: m => { REJECT = (m === null || m === undefined || m === false) ? null : String(m); },
  nowMs: () => NOW,
  setNow: v => { NOW = v; } };
