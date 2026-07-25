/**
 * timetap — server
 *
 * Automate capture. Never automate judgment.
 *
 * This file writes an ACTUAL calendar and a SITTING calendar, and reads a
 * PLAN calendar. It never writes to PLAN. It draws no conclusions.
 */

/* ═══════════════════════════════════════════════════════════════════
 * CONFIG — the only thing you edit
 * ═══════════════════════════════════════════════════════════════════ */

/** Calendar IDs. Settings -> the specific calendar -> Integrate calendar -> Calendar ID. */
var CAL_PLAN    = '';   // read-only. Your hand-written Sunday intent.
var CAL_ACTUAL  = '';   // written continuously by this app.
var CAL_SITTING = '';   // written continuously by this app. Posture overlay.

/**
 * Categories. Adding or removing one requires editing only this array —
 * the UI grid, the week report and the mark rules all lay out from here.
 *
 *   key      short uppercase token. Becomes the "KEY:" title prefix.
 *   label    human name, shown small under the key on the button.
 *   color    CalendarApp.EventColor.* — applied to the ACTUAL event.
 *   autoMark '+' | '=' | '-' | null.  Non-null means this category NEVER
 *            shows the mark strip; the mark is applied silently.
 */
var CATEGORIES = [
  { key: 'DW',   label: 'Deep work', color: CalendarApp.EventColor.BLUE,       autoMark: null },
  { key: 'MTG',  label: 'Meetings',  color: CalendarApp.EventColor.MAUVE,      autoMark: null },
  { key: 'ADM',  label: 'Admin',     color: CalendarApp.EventColor.GRAY,       autoMark: null },
  { key: 'BODY', label: 'Body',      color: CalendarApp.EventColor.GREEN,      autoMark: '+'  },
  { key: 'REL',  label: 'People',    color: CalendarApp.EventColor.ORANGE,     autoMark: null },
  { key: 'FRAG', label: 'Fragments', color: CalendarApp.EventColor.PALE_RED,   autoMark: '-'  }
];

/** Closed blocks shorter than this never get a mark and never show the strip. */
var MIN_MARK_MINUTES = 15;

/** A category tap this soon after the previous tap is a correction, not a transition. */
var MISTAP_SECONDS = 90;

/** On load, an open block older than this (or from a previous day) is bounded, not extended. */
var STALE_OPEN_HOURS = 5;

/** How long the mark strip waits before applying "=" silently. */
var MARK_TIMEOUT_MS = 6000;

/**
 * The one and only coupling in the app: tapping this category closes an open
 * SITTING block. Definitional, not inference. Set to '' to remove the coupling.
 */
var BODY_KEY = 'BODY';

/** Colour used for the recovery "UNLOGGED -" block written by stale handling. */
var UNLOGGED_COLOR = CalendarApp.EventColor.GRAY;

/** Flag the NOW bar once the open block passes this. Purely visual. */
var LONG_BLOCK_MINUTES = 90;

/* ═══════════════════════════════════════════════════════════════════
 * Constants — not configuration
 * ═══════════════════════════════════════════════════════════════════ */

var OPEN_TOKEN  = '#open';
var REF_PREFIX  = '#ref:';
var UNLOGGED_TITLE = 'UNLOGGED -';
var SIT_TITLE   = 'SIT';
var MS_HOUR     = 3600000;
var MS_MIN      = 60000;

/** Google Calendar's palette, so the client can tint buttons to match events. */
var COLOR_HEX = {
  '1': '#a4bdfc', '2': '#7ae7bf', '3': '#dbadff', '4': '#ff887c',
  '5': '#fbd75b', '6': '#ffb878', '7': '#46d6db', '8': '#9aa0a6',
  '9': '#5484ed', '10': '#51b749', '11': '#dc2127'
};

/* ═══════════════════════════════════════════════════════════════════
 * Web app entry
 * ═══════════════════════════════════════════════════════════════════ */

/**
 * Apps Script ignores meta tags written inside the HTML file and accepts only
 * four names through addMetaTag: viewport, apple-mobile-web-app-capable,
 * mobile-web-app-capable, google-site-verification. Anything else throws
 * "The meta tag you specified is not allowed in this context" at request time,
 * so this list is not the place to get creative.
 */
function doGet() {
  var t = HtmlService.createTemplateFromFile('Index');
  t.bootstrap = JSON.stringify(clientConfig_());
  return t.evaluate()
    .setTitle('timetap')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no')
    .addMetaTag('apple-mobile-web-app-capable', 'yes')
    .addMetaTag('mobile-web-app-capable', 'yes')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

/** Config the client needs. Touches no calendar, so it can never fail on a bad ID. */
function clientConfig_() {
  return {
    categories: CATEGORIES.map(function (c) {
      return {
        key: c.key,
        label: c.label,
        color: String(c.color),
        hex: COLOR_HEX[String(c.color)] || '#9aa0a6',
        autoMark: c.autoMark || null
      };
    }),
    minMarkMinutes: MIN_MARK_MINUTES,
    mistapSeconds: MISTAP_SECONDS,
    staleOpenHours: STALE_OPEN_HOURS,
    markTimeoutMs: MARK_TIMEOUT_MS,
    longBlockMinutes: LONG_BLOCK_MINUTES,
    bodyKey: BODY_KEY,
    tz: Session.getScriptTimeZone()
  };
}

/* ═══════════════════════════════════════════════════════════════════
 * Calendars
 * ═══════════════════════════════════════════════════════════════════ */

function calActual_()  { return openCal_(CAL_ACTUAL,  'CAL_ACTUAL'); }
function calSitting_() { return openCal_(CAL_SITTING, 'CAL_SITTING'); }
function calPlan_()    { return openCal_(CAL_PLAN,    'CAL_PLAN'); }

function openCal_(id, name) {
  if (!id) throw new Error(name + ' is empty in the CONFIG block of Code.gs.');
  var c = CalendarApp.getCalendarById(id);
  if (!c) throw new Error(name + ' does not resolve to a calendar you can open: ' + id);
  return c;
}

function catOf_(key) {
  for (var i = 0; i < CATEGORIES.length; i++) if (CATEGORIES[i].key === key) return CATEGORIES[i];
  return null;
}

/* ═══════════════════════════════════════════════════════════════════
 * Titles — ASCII marks only. Parsing depends on it.
 * ═══════════════════════════════════════════════════════════════════ */

function buildTitle_(key, text, mark) {
  var t = String(key || '').toUpperCase() + ':';
  var s = String(text == null ? '' : text).replace(/[\r\n]+/g, ' ').replace(/\s+/g, ' ').trim();
  if (s) t += ' ' + s;
  if (mark === '+' || mark === '=' || mark === '-') t += ' ' + mark;
  return t;
}

/**
 * "DW: memo drafting -"  ->  {key:'DW', text:'memo drafting', mark:'-'}
 * "ADM: ="               ->  {key:'ADM', text:'', mark:'='}
 * "UNLOGGED -"           ->  {key:'UNLOGGED', text:'', mark:'-'}
 * "Lunch with Ada"       ->  null
 */
function parseTitle_(title) {
  var raw = String(title == null ? '' : title).trim();
  var key = null, rest = null;
  var m = /^([A-Za-z0-9_]+)\s*:\s*([\s\S]*)$/.exec(raw);
  if (m) {
    key = m[1].toUpperCase();
    rest = m[2].trim();
  } else {
    var u = /^UNLOGGED\b([\s\S]*)$/.exec(raw);
    if (!u) return null;
    key = 'UNLOGGED';
    rest = u[1].trim();
  }
  var mark = null;
  var mm = /(?:^|\s)([+=\-])$/.exec(rest);
  if (mm) {
    mark = mm[1];
    rest = rest.slice(0, rest.length - 1).trim();
  }
  return { key: key, text: rest, mark: mark };
}

/* ═══════════════════════════════════════════════════════════════════
 * The open-block mechanism. The calendar is the source of truth.
 * ═══════════════════════════════════════════════════════════════════ */

function isOpenEvent_(ev) {
  return String(ev.getDescription() || '').indexOf(OPEN_TOKEN) >= 0;
}

function refOf_(ev) {
  var m = new RegExp(REF_PREFIX + '([A-Za-z0-9]+)').exec(String(ev.getDescription() || ''));
  if (m) return m[1];
  // An event that carries #open but no ref (hand-edited). Adopt it.
  var ref = newRef_();
  writeDesc_(ev, ref, isOpenEvent_(ev));
  return ref;
}

function newRef_() {
  return Utilities.getUuid().replace(/-/g, '').slice(0, 16);
}

/** Rewrite the description, preserving anything the user typed there. */
function writeDesc_(ev, ref, isOpen) {
  var d = String(ev.getDescription() || '');
  d = d.replace(new RegExp(REF_PREFIX + '[A-Za-z0-9]*', 'g'), '');
  d = d.replace(new RegExp(OPEN_TOKEN, 'g'), '');
  d = d.replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
  var tail = REF_PREFIX + ref + (isOpen ? '\n' + OPEN_TOKEN : '');
  ev.setDescription(d ? d + '\n' + tail : tail);
}

function findByRef_(cal, ref, hintMs) {
  if (!ref) return null;
  var h = hintMs || Date.now();
  var lo = new Date(Math.min(h, Date.now()) - 36 * MS_HOUR);
  var hi = new Date(Math.max(h, Date.now()) + 36 * MS_HOUR);
  var evs = cal.getEvents(lo, hi);
  var needle = REF_PREFIX + ref;
  for (var i = evs.length - 1; i >= 0; i--) {
    if (String(evs[i].getDescription() || '').indexOf(needle) >= 0) return evs[i];
  }
  return null;
}

/**
 * The newest #open event, having enforced the invariant: at most one per
 * calendar. Extras are closed at the newest one's start time.
 */
function findOpen_(cal) {
  var now = Date.now();
  var evs = cal.getEvents(new Date(now - 72 * MS_HOUR), new Date(now + 24 * MS_HOUR));
  var open = [];
  for (var i = 0; i < evs.length; i++) {
    if (evs[i].isAllDayEvent()) continue;
    if (isOpenEvent_(evs[i])) open.push(evs[i]);
  }
  if (!open.length) return null;
  open.sort(function (a, b) { return a.getStartTime().getTime() - b.getStartTime().getTime(); });
  var newest = open[open.length - 1];
  for (var j = 0; j < open.length - 1; j++) {
    endEventAt_(open[j], newest.getStartTime().getTime());
    writeDesc_(open[j], refOf_(open[j]), false);
  }
  return newest;
}

/** Never produce a zero-length or negative event, DST or clock skew regardless. */
function endEventAt_(ev, endMs) {
  var startMs = ev.getStartTime().getTime();
  var e = endMs;
  if (!(e > startMs)) e = startMs + MS_MIN;
  ev.setTime(new Date(startMs), new Date(e));
  return e;
}

/* ═══════════════════════════════════════════════════════════════════
 * Local time helpers. Epoch ms for durations, tz-aware for day borders.
 * ═══════════════════════════════════════════════════════════════════ */

function tz_() { return Session.getScriptTimeZone(); }

function ymd_(ms) { return Utilities.formatDate(new Date(ms), tz_(), 'yyyy-MM-dd'); }

function localMidnightMs_(ms) {
  var p = ymd_(ms).split('-');
  return new Date(+p[0], +p[1] - 1, +p[2], 0, 0, 0, 0).getTime();
}

function addLocalDaysMs_(ms, days) {
  var d = new Date(localMidnightMs_(ms));
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + days, 0, 0, 0, 0).getTime();
}

function mondayStartMs_(refMs, offsetWeeks) {
  var mid = localMidnightMs_(refMs);
  var d = new Date(mid);
  var back = (d.getDay() + 6) % 7;            // 0=Sun -> 6 back, 1=Mon -> 0 back
  return addLocalDaysMs_(mid, -back + (offsetWeeks || 0) * 7);
}

/* ═══════════════════════════════════════════════════════════════════
 * State — called on load, after the offline queue has drained
 * ═══════════════════════════════════════════════════════════════════ */

function getState() {
  var out = { nowMs: Date.now(), tz: tz_(), open: null, sit: null, notes: [] };

  var ca = calActual_();
  var evA = findOpen_(ca);
  evA = staleGuard_(ca, evA, true, out.notes);
  if (evA) {
    var p = parseTitle_(evA.getTitle()) || { key: 'ADM', text: '', mark: null };
    out.open = {
      ref: refOf_(evA),
      key: p.key,
      text: p.text,
      startMs: evA.getStartTime().getTime()
    };
  }

  var cs = calSitting_();
  var evS = findOpen_(cs);
  evS = staleGuard_(cs, evS, false, out.notes);
  if (evS) out.sit = { ref: refOf_(evS), startMs: evS.getStartTime().getTime() };

  return out;
}

/**
 * 9.2 — the user is never handed a fourteen-hour event.
 * Bound the block at start + STALE_OPEN_HOURS (also capped at the end of the
 * day it started on, and at now), then record the remainder as UNLOGGED.
 */
function staleGuard_(cal, ev, isActual, notes) {
  if (!ev) return null;
  var startMs = ev.getStartTime().getTime();
  var now = Date.now();
  var age = now - startMs;

  if (age < MISTAP_SECONDS * 1000) return ev;   // just opened, across midnight or not

  var crossedDay = ymd_(startMs) !== ymd_(now);
  if (age <= STALE_OPEN_HOURS * MS_HOUR && !crossedDay) return ev;

  var boundEnd = Math.min(startMs + STALE_OPEN_HOURS * MS_HOUR, now);
  if (crossedDay) boundEnd = Math.min(boundEnd, addLocalDaysMs_(startMs, 1));
  if (!(boundEnd > startMs)) boundEnd = startMs + MS_MIN;

  if (isActual) {
    var p = parseTitle_(ev.getTitle()) || { key: 'ADM', text: '', mark: null };
    var cat = catOf_(p.key);
    var mark = p.mark;
    if (!mark) {
      if (cat && cat.autoMark) mark = cat.autoMark;
      else if (boundEnd - startMs >= MIN_MARK_MINUTES * MS_MIN) mark = '=';
    }
    ev.setTitle(buildTitle_(p.key, p.text, mark));
  }
  endEventAt_(ev, boundEnd);
  writeDesc_(ev, refOf_(ev), false);

  if (isActual && now - boundEnd >= MS_MIN) {
    var un = cal.createEvent(UNLOGGED_TITLE, new Date(boundEnd), new Date(now),
      { description: REF_PREFIX + newRef_() });
    try { un.setColor(String(UNLOGGED_COLOR)); } catch (e) {}
    notes.push('bounded a stale block and wrote UNLOGGED to now');
  } else {
    notes.push('bounded a stale ' + (isActual ? 'block' : 'sit block'));
  }
  return null;
}

/* ═══════════════════════════════════════════════════════════════════
 * Ops — the offline queue drains through here, in order, idempotently
 * ═══════════════════════════════════════════════════════════════════ */

function applyOps(ops) {
  var out = { applied: [], errors: [] };
  if (!ops || !ops.length) return out;

  var lock = LockService.getUserLock();
  try { lock.waitLock(25000); } catch (e) {
    out.errors.push({ id: ops[0].id, message: 'busy' });
    return out;
  }
  try {
    for (var i = 0; i < ops.length; i++) {
      try {
        applyOp_(ops[i]);
        out.applied.push(ops[i].id);
      } catch (e) {
        // Stop at the first real failure so ordering is never broken.
        out.errors.push({ id: ops[i].id, message: String((e && e.message) || e) });
        break;
      }
    }
  } finally {
    try { lock.releaseLock(); } catch (e2) {}
  }
  return out;
}

function applyOp_(op) {
  switch (op.type) {
    case 'openActual':   return opOpenActual_(op);
    case 'closeActual':  return opCloseActual_(op);
    case 'recategorize': return opRecategorize_(op);
    case 'setMark':      return opSetMark_(op);
    case 'setText':      return opSetText_(op);
    case 'splitActual':  return opSplitActual_(op);
    case 'openSit':      return opOpenSit_(op);
    case 'closeSit':     return opCloseSit_(op);
    case 'setSitStart':  return opSetSitStart_(op);
    case 'deleteSit':    return opDeleteSit_(op);
    default: return;     // unknown op: drop it rather than wedge the queue
  }
}

function applyCatColor_(ev, key) {
  var cat = catOf_(key);
  if (!cat) return;
  try { ev.setColor(String(cat.color)); } catch (e) {}
}

function opOpenActual_(op) {
  var cal = calActual_();
  if (findByRef_(cal, op.ref, op.startMs)) return;      // replay: already created

  // Self-healing: whatever else is open on this calendar closes here.
  var prev = findOpen_(cal);
  if (prev && refOf_(prev) !== op.ref) {
    endEventAt_(prev, op.startMs);
    writeDesc_(prev, refOf_(prev), false);
  }

  var start = new Date(op.startMs);
  var ev = cal.createEvent(buildTitle_(op.key, '', null), start, new Date(op.startMs + MS_MIN));
  writeDesc_(ev, op.ref, true);
  applyCatColor_(ev, op.key);
}

function opCloseActual_(op) {
  var cal = calActual_();
  var ev = findByRef_(cal, op.ref, op.endMs);
  if (!ev) return;                                       // nothing to close: no-op
  var p = parseTitle_(ev.getTitle()) || { key: op.key || 'ADM', text: '', mark: null };
  var text = (typeof op.text === 'string') ? op.text : p.text;
  ev.setTitle(buildTitle_(p.key, text, op.mark || null));
  endEventAt_(ev, op.endMs);
  writeDesc_(ev, op.ref, false);
}

function opRecategorize_(op) {
  var cal = calActual_();
  var ev = findByRef_(cal, op.ref, op.hintMs);
  if (!ev) return;
  var p = parseTitle_(ev.getTitle()) || { key: op.key, text: '', mark: null };
  ev.setTitle(buildTitle_(op.key, p.text, p.mark));
  applyCatColor_(ev, op.key);
}

function opSetMark_(op) {
  var cal = calActual_();
  var ev = findByRef_(cal, op.ref, op.hintMs);
  if (!ev) return;
  var p = parseTitle_(ev.getTitle());
  if (!p) return;
  ev.setTitle(buildTitle_(p.key, p.text, op.mark || null));
}

function opSetText_(op) {
  var cal = calActual_();
  var ev = findByRef_(cal, op.ref, op.hintMs);
  if (!ev) return;
  var p = parseTitle_(ev.getTitle());
  if (!p) return;
  ev.setTitle(buildTitle_(p.key, op.text || '', p.mark));
}

/** 9.1 — close the open block at atMs, open the remainder there. One round trip. */
function opSplitActual_(op) {
  var cal = calActual_();
  var ev = findByRef_(cal, op.ref, op.atMs);
  if (ev) {
    var p = parseTitle_(ev.getTitle()) || { key: 'ADM', text: '', mark: null };
    var text = (typeof op.text === 'string') ? op.text : p.text;
    ev.setTitle(buildTitle_(p.key, text, op.mark || null));
    endEventAt_(ev, op.atMs);
    writeDesc_(ev, op.ref, false);
  }
  if (findByRef_(cal, op.newRef, op.atMs)) return;      // replay
  var end = Math.max(op.atMs + MS_MIN, op.nowMs || 0);
  var ne = cal.createEvent(buildTitle_(op.newKey, '', null), new Date(op.atMs), new Date(end));
  writeDesc_(ne, op.newRef, true);
  applyCatColor_(ne, op.newKey);
}

function opOpenSit_(op) {
  var cal = calSitting_();
  if (findByRef_(cal, op.ref, op.startMs)) return;
  var prev = findOpen_(cal);
  if (prev && refOf_(prev) !== op.ref) {
    endEventAt_(prev, op.startMs);
    writeDesc_(prev, refOf_(prev), false);
  }
  var ev = cal.createEvent(SIT_TITLE, new Date(op.startMs), new Date(op.startMs + MS_MIN));
  writeDesc_(ev, op.ref, true);
}

function opCloseSit_(op) {
  var cal = calSitting_();
  var ev = findByRef_(cal, op.ref, op.endMs);
  if (!ev) return;
  ev.setTitle(SIT_TITLE);
  endEventAt_(ev, op.endMs);
  writeDesc_(ev, op.ref, false);
}

function opSetSitStart_(op) {
  var cal = calSitting_();
  var ev = findByRef_(cal, op.ref, op.startMs);
  if (!ev) return;
  var end = ev.getEndTime().getTime();
  if (!(end > op.startMs)) end = op.startMs + MS_MIN;
  ev.setTime(new Date(op.startMs), new Date(end));
}

function opDeleteSit_(op) {
  var cal = calSitting_();
  var ev = findByRef_(cal, op.ref, op.hintMs);
  if (ev) ev.deleteEvent();
}

/* ═══════════════════════════════════════════════════════════════════
 * Week — raw numbers, and nothing else
 * ═══════════════════════════════════════════════════════════════════ */

function getWeek(offsetWeeks) {
  var startMs = mondayStartMs_(Date.now(), offsetWeeks || 0);
  var dayStarts = [];
  for (var i = 0; i < 8; i++) dayStarts.push(addLocalDaysMs_(startMs, i));
  var endMs = dayStarts[7];

  var plan   = readCal_(CAL_PLAN,    startMs, endMs);
  var actual = readCal_(CAL_ACTUAL,  startMs, endMs);
  var sit    = readCal_(CAL_SITTING, startMs, endMs);

  var planH = {}, actH = {}, switches = [0, 0, 0, 0, 0, 0, 0];
  var order = [];
  CATEGORIES.forEach(function (c) { order.push(c.key); planH[c.key] = 0; actH[c.key] = 0; });

  function bump(map, key, hours) {
    if (!(key in map)) { map[key] = 0; if (order.indexOf(key) < 0) order.push(key); }
    map[key] += hours;
  }

  plan.forEach(function (e) {
    var p = parseTitle_(e.title);
    if (!p) return;
    bump(planH, p.key, clipHours_(e, startMs, endMs));
    if (!(p.key in actH)) actH[p.key] = 0;
  });

  actual.forEach(function (e) {
    var p = parseTitle_(e.title);
    if (p) {
      bump(actH, p.key, clipHours_(e, startMs, endMs));
      if (!(p.key in planH)) planH[p.key] = 0;
    }
    var d = dayIndex_(e.start, dayStarts);
    if (d >= 0) switches[d]++;
  });

  // Waking span per day: first ACTUAL start -> last ACTUAL end, clipped to the day.
  var wakingH = 0;
  for (var d = 0; d < 7; d++) {
    var lo = dayStarts[d], hi = dayStarts[d + 1];
    var first = null, last = null;
    actual.forEach(function (e) {
      var s = Math.max(e.start, lo), t = Math.min(e.end, hi);
      if (!(t > s)) return;
      if (first === null || s < first) first = s;
      if (last === null || t > last) last = t;
    });
    if (first !== null && last !== null && last > first) wakingH += (last - first) / MS_HOUR;
  }

  var sitH = 0, longest = 0, over90 = 0;
  sit.forEach(function (e) {
    var s = Math.max(e.start, startMs), t = Math.min(e.end, endMs);
    var ms = t - s;
    if (!(ms > 0)) return;
    sitH += ms / MS_HOUR;
    if (ms > longest) longest = ms;
    if (ms > 90 * MS_MIN) over90++;
  });

  var L = [];
  L.push(ymd_(startMs) + ' .. ' + ymd_(dayStarts[6]));
  L.push('');
  order.forEach(function (k) {
    var ph = planH[k] || 0, ah = actH[k] || 0;
    if (ph === 0 && ah === 0 && !catOf_(k)) return;
    var ratio = ph > 0 ? (Math.round((ah / ph) * 100) / 100).toFixed(2) : '-';
    L.push(pad_(k, 6) + lpad_(fmtH_(ph), 6) + ' -> ' + pad_(fmtH_(ah), 7) + lpad_(ratio, 5));
  });
  L.push('');
  L.push('switches/day:' + switches.map(function (n) { return lpad_(String(n), 4); }).join(''));
  L.push('');
  L.push(pad_('SITTING', 10) + fmtH_(sitH) + 'h / ' + fmtH_(wakingH) + 'h waking' +
    lpad_(wakingH > 0 ? Math.round((sitH / wakingH) * 100) + '%' : '-', 7));
  L.push(pad_('longest unbroken sit', 24) + fmtHM_(longest));
  L.push(pad_('sits over 90 min', 24) + String(over90));

  return { text: L.join('\n'), startMs: startMs, endMs: endMs, offset: offsetWeeks || 0 };
}

/** Reads are tolerant: an unconfigured or unreadable calendar contributes nothing. */
function readCal_(id, startMs, endMs) {
  if (!id) return [];
  var cal;
  try { cal = CalendarApp.getCalendarById(id); } catch (e) { return []; }
  if (!cal) return [];
  var evs;
  try { evs = cal.getEvents(new Date(startMs), new Date(endMs)); } catch (e2) { return []; }
  var out = [];
  for (var i = 0; i < evs.length; i++) {
    if (evs[i].isAllDayEvent()) continue;
    out.push({
      title: evs[i].getTitle(),
      start: evs[i].getStartTime().getTime(),
      end: evs[i].getEndTime().getTime()
    });
  }
  return out;
}

function clipHours_(e, lo, hi) {
  var ms = Math.min(e.end, hi) - Math.max(e.start, lo);
  return ms > 0 ? ms / MS_HOUR : 0;
}

function dayIndex_(ms, dayStarts) {
  for (var i = 0; i < 7; i++) if (ms >= dayStarts[i] && ms < dayStarts[i + 1]) return i;
  return -1;
}

function fmtH_(h) {
  if (!h) return '0';
  var s = (Math.round(h * 100) / 100).toFixed(2);
  return s.replace(/0$/, '');
}

function fmtHM_(ms) {
  if (!(ms > 0)) return '0m';
  var mins = Math.round(ms / MS_MIN);
  var h = Math.floor(mins / 60), m = mins % 60;
  return h ? (h + 'h ' + m + 'm') : (m + 'm');
}

function pad_(s, n)  { s = String(s); return s.length >= n ? s + ' ' : s + new Array(n - s.length + 1).join(' '); }
function lpad_(s, n) { s = String(s); return s.length >= n ? ' ' + s : new Array(n - s.length + 1).join(' ') + s; }
