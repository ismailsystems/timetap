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

/**
 * Calendar IDs. Settings -> the specific calendar -> Integrate calendar -> Calendar ID.
 *
 * A script property of the same name wins over the literal here, and that is
 * the better place for them if you sync this repo with clasp: the IDs are the
 * only part of this file that is yours rather than the project's, and leaving
 * them out of it means git pull and clasp push can never fight over the one
 * line you care about. Project Settings -> Script properties. See SETUP.md 4.
 */
var CAL_PLAN    = '';   // read-only. Your hand-written Sunday intent.
var CAL_ACTUAL  = '';   // written continuously by this app.
var CAL_SITTING = '';   // written continuously by this app. Posture overlay.

/**
 * Categories. Adding or removing one requires editing only this array —
 * the UI grid, the week report and the mark rules all lay out from here.
 *
 *   key      short uppercase token. Becomes the "KEY:" title prefix and the
 *            row name in the week report. Never appears on the grid.
 *   label    what the button says, verbatim and full size. Write it to be read.
 *   color    CalendarApp.EventColor.* — the ACTUAL event's colour, and the
 *            button's background. See COLOR_HEX below for the eleven names.
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

/**
 * A category tap this soon after the previous one asks before it acts. The tap
 * arms the button instead of committing, and only a second tap on the same
 * button writes anything. Taps this close together are far more often a brush
 * than a decision, and the correction rule makes a brush destructive: it
 * silently retitles the block you are actually in.
 */
var CONFIRM_WITHIN_SECONDS = 60;

/** How long an armed button waits for that second tap before forgetting. */
var CONFIRM_TIMEOUT_MS = 4000;

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

/** Flag the open block's box once it passes this. Purely visual. */
var LONG_BLOCK_MINUTES = 90;

/**
 * Ceiling on how many categories the app will let you *add* from the grid's
 * "+" box; the box disappears once this many exist. It is deliberately not a
 * ceiling on CATEGORIES itself — silently discarding entries someone typed
 * into the file is worse than a grid that is one row taller than intended.
 */
var MAX_CATEGORIES = 10;

/** A queued write that fails this many times is set aside instead of retried. */
var MAX_OP_TRIES = 5;

/**
 * The rollup spreadsheet. Create one, copy the id out of its URL
 * (docs.google.com/spreadsheets/d/THIS_PART/edit) and paste it here — or set a
 * script property named SHEET_ID instead, same as the calendars. See SETUP.md 9.
 */
var SHEET_ID = '';

/** Tab names. Both are rebuilt from scratch on every run. */
var DAILY_TAB  = 'daily';
var WEEKLY_TAB = 'weekly';

/** How far back each run rebuilds. Cheap: three calendar reads regardless. */
var ROLLUP_DAYS = 90;

/** Hour of the day the trigger fires, in the script timezone. */
var ROLLUP_HOUR = 3;

/* ═══════════════════════════════════════════════════════════════════
 * Constants — not configuration
 * ═══════════════════════════════════════════════════════════════════ */

var OPEN_TOKEN  = '#open';
var REF_PREFIX  = '#ref:';
var UNLOGGED_TITLE = 'UNLOGGED -';
var SIT_TITLE   = 'SIT';
var MS_HOUR     = 3600000;
var MS_MIN      = 60000;

/**
 * Google Calendar's event palette, so a button is exactly the colour of the
 * event it writes. These are the eleven colours the Calendar UI renders today,
 * not the paler set the Calendar API's colors endpoint still reports, which is
 * why a button used to be a different shade from its own event.
 *
 *   EventColor    id   name        hex
 *   PALE_BLUE      1   Lavender    #7986cb
 *   PALE_GREEN     2   Sage        #33b679
 *   MAUVE          3   Grape       #8e24aa
 *   PALE_RED       4   Flamingo    #e67c73
 *   YELLOW         5   Banana      #f6bf26
 *   ORANGE         6   Tangerine   #f4511e
 *   CYAN           7   Peacock     #039be5
 *   GRAY           8   Graphite    #616161
 *   BLUE           9   Blueberry   #3f51b5
 *   GREEN         10   Basil       #0b8043
 *   RED           11   Tomato      #d50000
 */
var COLOR_HEX = {
  '1': '#7986cb', '2': '#33b679', '3': '#8e24aa', '4': '#e67c73',
  '5': '#f6bf26', '6': '#f4511e', '7': '#039be5', '8': '#616161',
  '9': '#3f51b5', '10': '#0b8043', '11': '#d50000'
};

/** WCAG relative luminance of a #rrggbb colour. */
function relLum_(hex) {
  var c = String(hex).replace('#', '');
  if (c.length === 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2];
  function ch(i) {
    var v = parseInt(c.substr(i, 2), 16) / 255;
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  }
  return 0.2126 * ch(0) + 0.7152 * ch(2) + 0.0722 * ch(4);
}

/** Contrast ratio between two colours, so the tests can police the palette. */
function contrast_(a, b) {
  var la = relLum_(a), lb = relLum_(b);
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

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
    categories: allCategories_().map(function (c) {
      return {
        key: c.key,
        label: c.label,
        color: String(c.color),
        hex: COLOR_HEX[String(c.color)] || '#616161',
        autoMark: c.autoMark || null
      };
    }),
    minMarkMinutes: MIN_MARK_MINUTES,
    mistapSeconds: MISTAP_SECONDS,
    confirmWithinSeconds: CONFIRM_WITHIN_SECONDS,
    confirmTimeoutMs: CONFIRM_TIMEOUT_MS,
    staleOpenHours: STALE_OPEN_HOURS,
    markTimeoutMs: MARK_TIMEOUT_MS,
    longBlockMinutes: LONG_BLOCK_MINUTES,
    maxCategories: MAX_CATEGORIES,
    maxOpTries: MAX_OP_TRIES,
    bodyKey: BODY_KEY,
    tz: Session.getScriptTimeZone()
  };
}

/* ═══════════════════════════════════════════════════════════════════
 * Calendars
 * ═══════════════════════════════════════════════════════════════════ */

/* No calPlan_(). PLAN is read through readCal_ only, so there is no handle in
   this file that could ever be used to write to it. */
function calActual_()  { return openCal_('CAL_ACTUAL'); }
function calSitting_() { return openCal_('CAL_SITTING'); }

var PROPS_ = null;   // one fetch per execution, not one per op

function prop_(name) {
  if (PROPS_ === null) {
    try { PROPS_ = PropertiesService.getScriptProperties().getProperties() || {}; }
    catch (e) { PROPS_ = {}; }
  }
  var v = PROPS_[name];
  return v ? String(v).trim() : '';
}

/** Script property first, CONFIG literal second. Trimmed, because a pasted ID
    carries a trailing space more often than not. */
function calId_(name) {
  var literal = { CAL_PLAN: CAL_PLAN, CAL_ACTUAL: CAL_ACTUAL, CAL_SITTING: CAL_SITTING }[name];
  return prop_(name) || String(literal || '').trim();
}

function openCal_(name) {
  var id = calId_(name);
  if (!id) {
    throw new Error(name + ' is not set. Put the calendar ID in the CONFIG block ' +
      'of Code.gs, or in a script property of the same name.');
  }
  var c = CalendarApp.getCalendarById(id);
  if (!c) throw new Error(name + ' does not resolve to a calendar you can open: ' + id);
  return c;
}

/**
 * Categories added from the grid live in a script property rather than in the
 * array above, because a running script cannot edit its own source. They are
 * appended to it, never merged into it, so CONFIG stays the thing you edit and
 * this stays the thing the app wrote.
 */
function extraCategories_() {
  var raw = prop_('EXTRA_CATEGORIES');
  if (!raw) return [];
  try {
    var a = JSON.parse(raw);
    return Array.isArray(a) ? a : [];
  } catch (e) { return []; }
}

function allCategories_() {
  var room = Math.max(0, MAX_CATEGORIES - CATEGORIES.length);
  return CATEGORIES.concat(extraCategories_().slice(0, room));
}

/**
 * Keys that used to be categories. The rollup still reports them, because the
 * events are still on the calendar and a report that quietly forgot a month of
 * them would be worse than a column of zeroes.
 */
function retiredKeys_() {
  var raw = prop_('RETIRED_KEYS');
  if (!raw) return [];
  try {
    var a = JSON.parse(raw);
    return Array.isArray(a) ? a : [];
  } catch (e) { return []; }
}

function catOf_(key) {
  var all = allCategories_();
  for (var i = 0; i < all.length; i++) if (all[i].key === key) return all[i];
  return null;
}

/**
 * The key is the calendar's vocabulary, so it has to be short, unique and
 * stable. It is derived once from the label and never changes — there is no
 * rename, here or anywhere, because renaming a key would split every past
 * event away from every future one in the rollup.
 */
function keyFor_(label, taken) {
  var base = String(label).toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 8) || 'CAT';
  var key = base, n = 2;
  var used = {};
  taken.forEach(function (c) { used[c.key] = 1; });
  while (used[key]) { key = base.slice(0, 7) + n; n++; }
  return key;
}

/** First colour in the palette nobody is using yet. */
function nextColor_(taken) {
  var used = {};
  taken.forEach(function (c) { used[String(c.color)] = 1; });
  for (var id = 1; id <= 11; id++) if (!used[String(id)]) return String(id);
  return String((taken.length % 11) + 1);
}

/**
 * Called from the grid's "+" box. Returns the config the client should adopt.
 *
 * Locked, because this is read-modify-write on a single property: two clients
 * adding at once without it and the second silently overwrites the first.
 */
function addCategory(label) {
  var name = String(label == null ? '' : label).replace(/\s+/g, ' ').trim().slice(0, 24);
  if (!name) throw new Error('A category needs a name.');

  var lock = LockService.getUserLock();
  try { lock.waitLock(20000); } catch (e) { throw new Error('Busy, try that again.'); }
  try {
    PROPS_ = null;                     // read fresh inside the lock, not before it
    var all = allCategories_();
    if (all.length >= MAX_CATEGORIES) {
      throw new Error('That is ' + MAX_CATEGORIES + ' categories already.');
    }
    for (var i = 0; i < all.length; i++) {
      if (all[i].label.toLowerCase() === name.toLowerCase()) {
        throw new Error('There is already a category called ' + all[i].label + '.');
      }
    }

    var extras = extraCategories_();
    extras.push({ key: keyFor_(name, all.concat(retiredKeys_())), label: name,
                  color: nextColor_(all), autoMark: null });
    PropertiesService.getScriptProperties().setProperty('EXTRA_CATEGORIES', JSON.stringify(extras));
    PROPS_ = null;                     // the cache is now a lie
    return clientConfig_();
  } finally {
    try { lock.releaseLock(); } catch (e2) {}
  }
}

/**
 * Remove one added category without touching the others. Run it from the
 * editor; there is deliberately no button for it, because a delete beside a
 * logging control is a delete that happens by accident.
 *
 * Only categories added from the grid can go — the ones in CATEGORIES are
 * yours to edit in the file. The key is remembered as retired so the rollup
 * keeps reporting the events already logged under it.
 */
function removeCategory(key) {
  var want = String(key == null ? '' : key).trim().toUpperCase();
  if (!want) throw new Error('Which key?');

  var lock = LockService.getUserLock();
  try { lock.waitLock(20000); } catch (e) { throw new Error('Busy, try that again.'); }
  try {
    PROPS_ = null;
    var extras = extraCategories_();
    var keep = extras.filter(function (c) { return c.key !== want; });
    if (keep.length === extras.length) {
      if (CATEGORIES.some(function (c) { return c.key === want; })) {
        throw new Error(want + ' is in the CATEGORIES array. Remove it from Code.gs.');
      }
      throw new Error('No added category with key ' + want + '.');
    }
    var gone = extras.filter(function (c) { return c.key === want; })[0];

    var retired = retiredKeys_();
    if (!retired.some(function (r) { return r.key === want; })) {
      retired.push({ key: want, label: gone.label });
    }
    var props = PropertiesService.getScriptProperties();
    props.setProperty('EXTRA_CATEGORIES', JSON.stringify(keep));
    props.setProperty('RETIRED_KEYS', JSON.stringify(retired));
    PROPS_ = null;
    return 'removed ' + want + '; its history stays in the rollup';
  } finally {
    try { lock.releaseLock(); } catch (e2) {}
  }
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

/**
 * A queued op is only as trustworthy as the localStorage it came out of. An op
 * that cannot possibly succeed is dropped rather than thrown, because throwing
 * would leave it at the head of the queue blocking every write behind it.
 */
function validOp_(op) {
  if (!op || typeof op !== 'object') return false;
  if (typeof op.type !== 'string' || !op.type) return false;
  if (typeof op.id !== 'string' || !op.id) return false;
  var ms = ['startMs', 'endMs', 'atMs', 'nowMs', 'hintMs'];
  for (var i = 0; i < ms.length; i++) {
    var v = op[ms[i]];
    if (v !== undefined && v !== null && !(typeof v === 'number' && isFinite(v))) return false;
  }
  var refs = ['ref', 'newRef'];
  for (var j = 0; j < refs.length; j++) {
    var r = op[refs[j]];
    if (r !== undefined && !/^[A-Za-z0-9]{4,64}$/.test(String(r))) return false;
  }
  if (op.mark !== undefined && op.mark !== null && '+=-'.indexOf(op.mark) < 0) return false;
  return true;
}

function applyOps(ops) {
  var out = { applied: [], errors: [], dropped: [] };
  if (!ops || !ops.length) return out;

  var lock = LockService.getUserLock();
  try { lock.waitLock(25000); } catch (e) {
    out.errors.push({ id: ops[0].id, message: 'busy' });
    return out;
  }
  try {
    for (var i = 0; i < ops.length; i++) {
      if (!validOp_(ops[i])) {
        // Applied in the sense that the client should stop holding it.
        out.dropped.push({ id: (ops[i] && ops[i].id) || null, op: ops[i] });
        if (ops[i] && ops[i].id) out.applied.push(ops[i].id);
        continue;
      }
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
 * Rollup — raw numbers into a spreadsheet, and nothing else
 *
 * There is no week screen. The numbers go to a sheet on a daily trigger and
 * you read them where you do your thinking, which was never the phone.
 *
 * Both tabs are rebuilt from the calendars on every run, for the whole
 * ROLLUP_DAYS window. That makes the job idempotent, lets a retroactive
 * calendar edit correct itself, and keeps the columns honest when CATEGORIES
 * changes. It also means these tabs are generated output: anything you type
 * into them is erased overnight. Put your own work in another tab and point
 * formulas at these.
 * ═══════════════════════════════════════════════════════════════════ */

/** Entry point for the daily time-driven trigger. Safe to run by hand. */
function dailyRollup() {
  var ss = openSheet_();
  var todayStart = localMidnightMs_(Date.now());
  var firstDay = addLocalDaysMs_(todayStart, -(ROLLUP_DAYS - 1));
  var endMs = addLocalDaysMs_(todayStart, 1);

  var plan   = readCal_(calId_('CAL_PLAN'),    firstDay, endMs);
  var actual = readCal_(calId_('CAL_ACTUAL'),  firstDay, endMs);
  var sit    = readCal_(calId_('CAL_SITTING'), firstDay, endMs);

  var keys = rollupKeys_();
  var days = [];
  for (var i = 0; i < ROLLUP_DAYS; i++) {
    var s = addLocalDaysMs_(firstDay, i);
    days.push(dayStats_(s, addLocalDaysMs_(s, 1), plan, actual, sit, keys));
  }

  writeGrid_(ss, DAILY_TAB, dailyGrid_(days, keys));
  writeGrid_(ss, WEEKLY_TAB, weeklyGrid_(days, keys));
  return { days: days.length, categories: keys.length, sheet: ss.getUrl() };
}

/**
 * The keys the rollup reports: the ones you configured, the ones you retired,
 * and UNLOGGED. Deliberately not "whatever the calendars mention".
 *
 * PLAN is hand-written by design, and parseTitle_ cannot tell a category from
 * any other text before a colon: "9:00 standup" reads as key 9, "Dinner: with
 * Ada" as DINNER, "Re: the thing" as RE. Discovering keys from titles turned
 * ordinary calendar entries into columns and would have gone on doing it.
 */
function rollupKeys_() {
  var keys = allCategories_().map(function (c) { return c.key; });
  retiredKeys_().forEach(function (r) { if (keys.indexOf(r.key) < 0) keys.push(r.key); });
  keys.push('UNLOGGED');
  return keys;
}

/** Everything the day is, as numbers. No ratios, no commentary. */
function dayStats_(lo, hi, plan, actual, sit, keys) {
  var d = { ms: lo, ymd: ymd_(lo), dow: new Date(lo).getDay(),
            plan: {}, actual: {}, switches: 0, waking: 0, sitting: 0,
            longestSit: 0, sitsOver90: 0 };
  keys.forEach(function (k) { d.plan[k] = 0; d.actual[k] = 0; });

  plan.forEach(function (e) {
    var p = parseTitle_(e.title);
    if (p && (p.key in d.plan)) d.plan[p.key] += clipHours_(e, lo, hi);
  });

  var first = null, last = null;
  actual.forEach(function (e) {
    var p = parseTitle_(e.title);
    if (p && (p.key in d.actual)) d.actual[p.key] += clipHours_(e, lo, hi);
    if (e.start >= lo && e.start < hi) d.switches++;
    var s = Math.max(e.start, lo), t = Math.min(e.end, hi);
    if (t > s) {
      if (first === null || s < first) first = s;
      if (last === null || t > last) last = t;
    }
  });
  if (first !== null && last > first) d.waking = (last - first) / MS_HOUR;

  sit.forEach(function (e) {
    var ms = Math.min(e.end, hi) - Math.max(e.start, lo);
    if (!(ms > 0)) return;
    d.sitting += ms / MS_HOUR;
    if (ms > d.longestSit) d.longestSit = ms;
    if (ms > 90 * MS_MIN) d.sitsOver90++;
  });
  return d;
}

var DOW_ = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/** One row per day. The rawest thing the calendars can say. */
function dailyGrid_(days, keys) {
  var head = ['date', 'day'];
  keys.forEach(function (k) { head.push(k); });
  keys.forEach(function (k) { head.push('plan ' + k); });
  head = head.concat(['switches', 'waking h', 'sitting h', 'sitting %',
                      'longest sit min', 'sits over 90']);

  var rows = [head];
  days.forEach(function (d) {
    var r = [d.ymd, DOW_[d.dow]];
    keys.forEach(function (k) { r.push(round2_(d.actual[k])); });
    keys.forEach(function (k) { r.push(round2_(d.plan[k])); });
    r.push(d.switches, round2_(d.waking), round2_(d.sitting),
           d.waking > 0 ? round2_(d.sitting / d.waking) : '',
           Math.round(d.longestSit / MS_MIN), d.sitsOver90);
    rows.push(r);
  });
  return rows;
}

/** The same numbers grouped Monday to Sunday, with the planned-versus-actual
    ratio the weekly ritual actually compares. */
function weeklyGrid_(days, keys) {
  var head = ['week of'];
  keys.forEach(function (k) { head.push('plan ' + k, k, k + ' ratio'); });
  head = head.concat(['switches', 'waking h', 'sitting h', 'sitting %',
                      'longest sit min', 'sits over 90']);

  var weeks = [], index = {};
  days.forEach(function (d) {
    var wk = ymd_(mondayStartMs_(d.ms, 0));
    if (!(wk in index)) {
      index[wk] = weeks.length;
      var blank = { wk: wk, plan: {}, actual: {}, switches: 0, waking: 0,
                    sitting: 0, longestSit: 0, sitsOver90: 0 };
      keys.forEach(function (k) { blank.plan[k] = 0; blank.actual[k] = 0; });
      weeks.push(blank);
    }
    var w = weeks[index[wk]];
    keys.forEach(function (k) { w.plan[k] += d.plan[k]; w.actual[k] += d.actual[k]; });
    w.switches += d.switches;
    w.waking += d.waking;
    w.sitting += d.sitting;
    w.sitsOver90 += d.sitsOver90;
    if (d.longestSit > w.longestSit) w.longestSit = d.longestSit;
  });

  var rows = [head];
  weeks.forEach(function (w) {
    var r = [w.wk];
    keys.forEach(function (k) {
      r.push(round2_(w.plan[k]), round2_(w.actual[k]),
             w.plan[k] > 0 ? round2_(w.actual[k] / w.plan[k]) : '');
    });
    r.push(w.switches, round2_(w.waking), round2_(w.sitting),
           w.waking > 0 ? round2_(w.sitting / w.waking) : '',
           Math.round(w.longestSit / MS_MIN), w.sitsOver90);
    rows.push(r);
  });
  return rows;
}

function round2_(n) { return Math.round((n || 0) * 100) / 100; }

/* ── the spreadsheet ────────────────────────────────────────────── */

function openSheet_() {
  var id = prop_('SHEET_ID') || String(SHEET_ID || '').trim();
  if (!id) {
    throw new Error('SHEET_ID is not set. Create a spreadsheet, take the id out ' +
      'of its URL, and put it in the CONFIG block of Code.gs or in a script ' +
      'property named SHEET_ID.');
  }
  var ss = SpreadsheetApp.openById(id);
  if (!ss) throw new Error('SHEET_ID does not resolve to a spreadsheet you can open: ' + id);
  return ss;
}

/** Replace the tab's contents wholesale. Values only: no formatting opinions. */
function writeGrid_(ss, tabName, rows) {
  var sh = ss.getSheetByName(tabName) || ss.insertSheet(tabName);
  sh.clear();
  if (!rows.length) return;
  var width = 0;
  rows.forEach(function (r) { if (r.length > width) width = r.length; });
  rows.forEach(function (r) { while (r.length < width) r.push(''); });
  sh.getRange(1, 1, rows.length, width).setValues(rows);
  sh.setFrozenRows(1);
}

/* ── the trigger ────────────────────────────────────────────────── */

/**
 * Run once from the editor. Idempotent: clears any trigger it previously made
 * before installing the new one, so running it twice does not double up.
 */
function installDailyTrigger() {
  removeDailyTrigger();
  ScriptApp.newTrigger('dailyRollup').timeBased().atHour(ROLLUP_HOUR).everyDays(1).create();
  return 'dailyRollup will run daily around ' + ROLLUP_HOUR + ':00 ' + tz_();
}

function removeDailyTrigger() {
  var gone = 0;
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'dailyRollup') { ScriptApp.deleteTrigger(t); gone++; }
  });
  return 'removed ' + gone;
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
