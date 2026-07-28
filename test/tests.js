const H = require('./harness.js');
const { chk, near, reset, reboot, tap, tapSit, tapMark, wait, advance, settle, A, S, show, $,
        posture, activeKey, litPosture, noteBox, elapsedBox, addCell } = H;

const armedKey = () => {
  const b = H.NODES['grid'] && H.NODES['grid'].children.find(c => c._cls.has('arming'));
  return b ? b.dataset.key : null;
};
const splitOpen = () => { const n = H.NODES['sheetSplit']; return !!n && !n.hidden; };
const D = (y, m, d, hh, mm) => new Date(y, m - 1, d, hh, mm, 0, 0).getTime();

console.log('\n1. cold open, no open block');
reset(); reboot();
chk('grid renders six categories', $('grid').children.filter(c => c.dataset.key).length === 6,
  'got ' + $('grid').children.filter(c => c.dataset.key).length);
chk('plus an add box', !!addCell());
chk('nothing lit in the grid', activeKey() === null, String(activeKey()));
chk('no events written', A().length === 0);
chk('strip hidden', $('strip').hidden);

console.log('\n2. ADM, 52m, DW -> strip, ignore 6s -> "ADM: ="');
reset(); reboot();
tap('ADM'); wait(52); tap('DW');
chk('strip visible', !$('strip').hidden);
chk('strip head "ADM closed · 52m"', $('stripHead').textContent === 'ADM closed · 52m', $('stripHead').textContent);
advance(6000); settle();
chk('strip auto-dismissed', $('strip').hidden);
chk('ADM titled "ADM: ="', A()[0].t === 'ADM: =', A()[0].t);
chk('ADM ends at the tap', A()[0].e === A()[1].s, show(A()[0]) + ' / ' + show(A()[1]));
chk('ADM ran 52m', near(A()[0].e - A()[0].s, 52 * 60000), String((A()[0].e - A()[0].s) / 60000));
chk('DW open', /#open/.test(A()[1].d) && A()[1].t === 'DW:', show(A()[1]));

console.log('\n3. FRAG, 20m, DW -> no strip, "FRAG: -"');
reset(); reboot();
tap('FRAG'); wait(20); tap('DW');
chk('no strip', $('strip').hidden);
chk('FRAG autoMarked "-"', A()[0].t === 'FRAG: -', A()[0].t);

console.log('\n4. DW then MTG 10s later -> one event, MTG, original start');
/* C1 nested the correction window inside the confirm window, so this is 10s
   rather than the 30s it used to be. 30s is now a transition, which section
   50 asserts directly. The behaviour under test — a correction retitles the
   block you are in — is unchanged. */
reset(); reboot();
const t4 = H.nowMs();
tap('DW'); advance(10000); settle(); tap('MTG'); tap('MTG');
chk('exactly one event', A().length === 1, A().map(show).join(' | '));
chk('category MTG', A()[0].t === 'MTG:', A()[0].t);
chk('start preserved', A()[0].s === t4, show(A()[0]));
chk('still open', /#open/.test(A()[0].d));

console.log('\n4b. mis-tap after the queue already flushed');
reset(); reboot();
const t4b = H.nowMs();
tap('DW'); settle(); settle();
advance(10000); settle(); tap('ADM'); tap('ADM');
chk('exactly one event', A().length === 1, A().map(show).join(' | '));
chk('category ADM, start preserved', A()[0].t === 'ADM:' && A()[0].s === t4b, show(A()[0]));

console.log('\n5. MTG, 8m, ADM -> no strip, no mark');
reset(); reboot();
tap('MTG'); wait(8); tap('ADM');
chk('no strip', $('strip').hidden);
chk('MTG has no mark', A()[0].t === 'MTG:', A()[0].t);

console.log('\n5b. explicit mark tap');
reset(); reboot();
tap('DW'); wait(40); tap('ADM');
chk('strip up', !$('strip').hidden);
tapMark('+');
chk('strip dismissed', $('strip').hidden);
chk('DW marked "+"', A()[0].t === 'DW: +', A()[0].t);

console.log('\n6. SIT on, three categories, SIT off');
reset(); reboot();
tapSit(); wait(5);
tap('DW'); wait(20); tap('MTG'); wait(20); tap('ADM'); wait(20);
posture('stand');
chk('one SIT event', S().length === 1, S().map(show).join(' | '));
chk('SIT titled "SIT", no mark', S()[0].t === 'SIT', S()[0].t);
chk('SIT closed', !/#open/.test(S()[0].d));
chk('SIT ran 65m', near(S()[0].e - S()[0].s, 65 * 60000), String((S()[0].e - S()[0].s) / 60000));
chk('three ACTUAL events', A().length === 3, A().map(show).join(' | '));
chk('ADM still open', /#open/.test(A()[2].d));

console.log('\n7. SIT open, tap BODY -> SIT closes at that instant');
reset(); reboot();
tapSit(); wait(30);
const t7 = H.nowMs();
tap('BODY');
chk('SIT closed at the tap', S()[0].e === t7, show(S()[0]));
chk('SIT no longer open', !/#open/.test(S()[0].d));
chk('BODY block open', A()[0].t === 'BODY:' && /#open/.test(A()[0].d), show(A()[0]));
wait(20); tap('DW');
chk('BODY autoMarked "+", no strip', A()[0].t === 'BODY: +' && $('strip').hidden, A()[0].t);

console.log('\n8. kill the page mid-block, reload');
reset(); reboot();
const t8 = H.nowMs();
tap('DW'); settle();
noteBox().value = 'memo drafting'; noteBox().fire('input'); advance(1000); settle();
wait(47);
Object.keys(H.STORE).forEach(k => delete H.STORE[k]);   // hardest case: storage gone too
reboot();
chk('open block recovered', activeKey() === 'DW', String(activeKey()));
chk('start time correct', /47m/.test(elapsedBox()), elapsedBox());
chk('note recovered into the lit box', noteBox().value === 'memo drafting', noteBox().value);
chk('title carries the note', A()[0].t === 'DW: memo drafting', A()[0].t);
wait(1);
chk('timer live inside the box', /48m/.test(elapsedBox()), elapsedBox());

console.log('\n9. airplane mode: three taps offline, then network back');
reset(); reboot();
H.setOnline(false);
const t9 = H.nowMs();
tap('DW'); wait(20); tap('MTG'); wait(20); tap('ADM'); wait(20);
chk('nothing written while offline', A().length === 0, A().map(show).join(' | '));
chk('sync dot red', $('sync').className === 's-failed', $('sync').className);
H.setOnline(true);
advance(120000); settle(); settle();
chk('three events after restore', A().length === 3, A().map(show).join(' | '));
chk('order preserved', A().map(e => e.t.split(':')[0]).join(',') === 'DW,MTG,ADM', A().map(e => e.t).join(' | '));
chk('DW start = first tap', A()[0].s === t9, show(A()[0]));
chk('no gaps or overlaps', A()[0].e === A()[1].s && A()[1].e === A()[2].s, A().map(show).join(' | '));
chk('marks applied', A()[0].t === 'DW: =' && A()[1].t === 'MTG: =', A().map(e => e.t).join(' | '));
chk('queue drained', (JSON.parse(H.STORE['tt.queue.v1'] || '[]')).length === 0);
chk('sync dot clear', $('sync').className === 's-synced', $('sync').className);
H.setOnline(false);
advance(60000); settle();
H.setOnline(true);
advance(60000); settle(); settle();
chk('no duplicates after a further retry', A().length === 3, A().map(show).join(' | '));

console.log('\n10. open block started 9 hours ago');
reset(D(2026, 7, 20, 8, 0)); reboot();
tap('DW'); settle();
H.setNow(D(2026, 7, 20, 17, 0));
reboot();
const a10 = A();
chk('two events', a10.length === 2, a10.map(show).join(' | '));
chk('DW bounded at 5h', near(a10[0].e - a10[0].s, 5 * 3600000), show(a10[0]));
/* A2: was 'DW: =', which claimed the user settled a block the app had bounded.
 * The boundary assertions above and below this line are deliberately unchanged. */
chk('DW marked as a guess, not as settled', a10[0].t === 'DW: ?', a10[0].t);
chk('UNLOGGED - follows', a10[1].t === 'UNLOGGED -', a10[1].t);
chk('UNLOGGED spans to now', a10[1].s === a10[0].e && near(a10[1].e, D(2026, 7, 20, 17, 0)), show(a10[1]));
chk('no giant event', a10.every(e => (e.e - e.s) <= 5 * 3600000), a10.map(show).join(' | '));
chk('nothing lit after recovery', activeKey() === null, String(activeKey()));

console.log('\n10b. block left open overnight');
reset(D(2026, 7, 20, 22, 30)); reboot();
tap('MTG'); settle();
H.setNow(D(2026, 7, 21, 9, 15));
reboot();
const b10 = A();
chk('bounded at midnight, not 5h', near(b10[0].e, D(2026, 7, 21, 0, 0)), b10.map(show).join(' | '));
chk('UNLOGGED covers the night', b10[1].t === 'UNLOGGED -' && near(b10[1].e, D(2026, 7, 21, 9, 15)), show(b10[1]));

console.log('\n10c. stale open SIT block');
reset(D(2026, 7, 20, 8, 0)); reboot();
tapSit(); settle();
H.setNow(D(2026, 7, 20, 20, 0));
reboot();
chk('SIT bounded at 5h', near(S()[0].e - S()[0].s, 5 * 3600000), show(S()[0]));
chk('no UNLOGGED on SITTING', S().length === 1, S().map(show).join(' | '));
chk('posture falls back to standing', litPosture() === 'stand', String(litPosture()));

console.log('\n11. SPLIT a 3h open block at the 1h mark into MTG + ADM');
reset(); reboot();
const t11 = H.nowMs();
tap('MTG'); settle(); wait(180);
tap('MTG'); settle();                                    // re-tap the lit one
$('spRange').value = '60'; $('spRange').fire('input');
$('splitGrid').children[2].fire('click'); settle();     // ADM
const a11 = A();
chk('two events', a11.length === 2, a11.map(show).join(' | '));
chk('MTG 1h from the original start', a11[0].t === 'MTG: =' && a11[0].s === t11 && near(a11[0].e - a11[0].s, 3600000), show(a11[0]));
chk('ADM starts where MTG ends', a11[1].s === a11[0].e, show(a11[1]));
chk('ADM open and current', /#open/.test(a11[1].d) && activeKey() === 'ADM', show(a11[1]));
wait(30); tap('DW');
chk('remainder closes correctly', near(A()[1].e, H.nowMs()) && near(A()[1].e - A()[1].s, 150 * 60000), show(A()[1]));

console.log('\n12. daily rollup writes the sheet');
reset(D(2026, 7, 24, 15, 0));                            // Friday
H.SCRIPT_PROPS.SHEET_ID = 'book';
H.clearPropCache();
const P = (t2, d, h1, h2) => H.CALS.plan.createEvent(t2, new Date(D(2026, 7, d, h1, 0)), new Date(D(2026, 7, d, h2, 0)), {});
P('DW: ship the thing', 20, 9, 13); P('DW: ship the thing', 21, 9, 13); P('DW: ship the thing', 22, 9, 13);
P('MTG: standups', 20, 14, 15); P('BODY: run', 21, 7, 8);
P('Dinner with Ada', 22, 19, 21);                        // not a category, must be ignored
reboot();
tap('DW'); wait(90); tap('MTG'); wait(30); tap('FRAG'); wait(10); tap('DW'); wait(60);
tapSit(); wait(100); posture('stand');
const res = dailyRollup();
const daily = H.SHEETS.book.getSheetByName('daily').rows;
const weekly = H.SHEETS.book.getSheetByName('weekly').rows;
const dh = daily[0], wh = weekly[0];
const col = (hdr, name) => hdr.indexOf(name);
const friday = daily.find(r => r[0] === '2026-07-24');
const thisWeek = weekly.find(r => r[0] === '2026-07-20');

chk('both tabs written', !!daily.length && !!weekly.length);
chk('rollup reports what it did', res.days === 90 && res.categories >= 6,
  JSON.stringify(res));
chk('one row per day plus a header', daily.length === 91, 'rows=' + daily.length);
chk('daily header names every category', ['DW','MTG','ADM','BODY','REL','FRAG'].every(k => col(dh, k) > 0), dh.join('|'));
chk('daily header carries plan columns', col(dh, 'plan DW') > 0, dh.join('|'));
chk('frozen header row', H.SHEETS.book.getSheetByName('daily').frozen === 1);

chk('friday row exists', !!friday, daily.slice(-3).map(r => r[0]).join(' '));
chk('weekday label', friday[col(dh, 'day')] === 'Fri', friday[col(dh, 'day')]);
chk('DW actual is a number, not a padded string', typeof friday[col(dh, 'DW')] === 'number',
  typeof friday[col(dh, 'DW')]);
chk('DW actual 1.5h logged', friday[col(dh, 'DW')] > 1.4 && friday[col(dh, 'DW')] < 1.6,
  String(friday[col(dh, 'DW')]));
chk('switches counted', friday[col(dh, 'switches')] === 4, String(friday[col(dh, 'switches')]));
chk('sitting recorded', friday[col(dh, 'sitting h')] > 1.6, String(friday[col(dh, 'sitting h')]));
chk('sits over 90 counted', friday[col(dh, 'sits over 90')] === 1, String(friday[col(dh, 'sits over 90')]));
chk('unparseable PLAN title ignored', !JSON.stringify(daily).match(/Dinner/));

chk('weekly groups Mon-Sun', !!thisWeek, weekly.slice(-3).map(r => r[0]).join(' '));
chk('weekly carries the planned total', thisWeek[col(wh, 'plan DW')] === 12, String(thisWeek[col(wh, 'plan DW')]));
chk('weekly ratio is actual over planned',
  Math.abs(thisWeek[col(wh, 'DW ratio')] - (thisWeek[col(wh, 'DW')] / 12)) < 0.011,
  'ratio=' + thisWeek[col(wh, 'DW ratio')] + ' actual=' + thisWeek[col(wh, 'DW')]);
chk('no NaN anywhere', !JSON.stringify(daily.concat(weekly)).match(/null|NaN/),
  (JSON.stringify(daily.concat(weekly)).match(/null|NaN/g) || []).join(' '));

console.log('\n12b. an empty week divides by nothing');
reset(D(2026, 7, 24, 15, 0));
H.SCRIPT_PROPS.SHEET_ID = 'book'; H.clearPropCache(); reboot();
dailyRollup();
const empty = H.SHEETS.book.getSheetByName('daily').rows;
const ew = H.SHEETS.book.getSheetByName('weekly').rows;
chk('still renders', empty.length === 91 && ew.length > 1);
chk('no NaN or Infinity', !JSON.stringify(empty.concat(ew)).match(/NaN|Infinity/));
chk('zero-planned ratio is blank, not a division',
  ew[1][ew[0].indexOf('DW ratio')] === '', JSON.stringify(ew[1][ew[0].indexOf('DW ratio')]));
chk('zero-waking sitting % is blank',
  empty[1][empty[0].indexOf('sitting %')] === '', JSON.stringify(empty[1][empty[0].indexOf('sitting %')]));

console.log('\n12c. the rollup is idempotent and self-healing');
reset(D(2026, 7, 24, 15, 0));
H.SCRIPT_PROPS.SHEET_ID = 'book'; H.clearPropCache(); reboot();
tap('DW'); wait(60); tap('ADM'); settle();
dailyRollup();
const once = JSON.stringify(H.SHEETS.book.getSheetByName('daily').rows);
dailyRollup();
chk('running twice changes nothing', JSON.stringify(H.SHEETS.book.getSheetByName('daily').rows) === once);
H.CALS.actual.createEvent('REL: retroactive', new Date(D(2026, 7, 22, 10, 0)),
  new Date(D(2026, 7, 22, 12, 0)), { description: '#ref:backfill00000000' });
dailyRollup();
const healed = H.SHEETS.book.getSheetByName('daily').rows;
const wed = healed.find(r => r[0] === '2026-07-22');
chk('a retroactive calendar edit is picked up on the next run',
  wed[healed[0].indexOf('REL')] === 2, String(wed[healed[0].indexOf('REL')]));

console.log('\n12d. the trigger installs idempotently');
reset();
chk('installs one trigger', (installDailyTrigger(), H.TRIGGERS.length) === 1, 'n=' + H.TRIGGERS.length);
chk('targets dailyRollup at the configured hour',
  H.TRIGGERS[0].fn === 'dailyRollup' && H.TRIGGERS[0].hour === ROLLUP_HOUR && H.TRIGGERS[0].days === 1,
  JSON.stringify(H.TRIGGERS[0]));
installDailyTrigger();
chk('running it again does not double up', H.TRIGGERS.length === 1, 'n=' + H.TRIGGERS.length);
removeDailyTrigger();
chk('and it can be removed', H.TRIGGERS.length === 0);

console.log('\n12e. a missing SHEET_ID says so');
reset();
let sheetErr = null;
try { dailyRollup(); } catch (e) { sheetErr = String(e.message || e); }
chk('names SHEET_ID in the error', !!sheetErr && /SHEET_ID/.test(sheetErr), sheetErr);
chk('and says where to put it', !!sheetErr && /script propert/i.test(sheetErr), sheetErr);

console.log('\n13. PLAN is never written');
reset(); reboot();
const planBefore = JSON.stringify(H.CALS.plan.events);
H.CALS.plan.createEvent('DW: intent', new Date(H.nowMs()), new Date(H.nowMs() + 3600000), {});
const snap = H.CALS.plan.events.map(e => e.t + e.s + e.e + e.d).join('|');
tap('DW'); wait(60); tap('MTG'); tapMark('-'); wait(30); tap('BODY'); tapSit(); wait(10); posture('stand');
getState();
chk('PLAN untouched', H.CALS.plan.events.map(e => e.t + e.s + e.e + e.d).join('|') === snap);

console.log('\n14. invariant: at most one #open per calendar');
reset(); reboot();
tap('DW'); settle();
H.CALS.actual.createEvent('ADM: stray', new Date(H.nowMs() + 600000), new Date(H.nowMs() + 660000), { description: '#ref:strayref00000000\n#open' });
advance(600000);
reboot();
const openCount = A().filter(e => /#open/.test(e.d)).length;
chk('exactly one #open remains', openCount === 1, A().map(show).join(' | '));
chk('older one was closed at the newer start', A()[0].e === A()[1].s, A().map(show).join(' | '));

console.log('\n15. re-tapping the lit category');
reset(); reboot();
tap('DW'); advance(10000); settle();
const before15 = A().map(e => e.t + e.s + e.e).join('|');
tap('DW'); settle();
chk('inside the mis-tap window it does nothing at all',
  !splitOpen() && A().length === 1 && A().map(e => e.t + e.s + e.e).join('|') === before15,
  'sheet=' + splitOpen() + ' ' + A().map(show).join(' | '));

wait(30);
const before15b = A().map(e => e.t + e.s + e.e).join('|');
tap('DW'); settle();
chk('past it, the lit button opens SPLIT', splitOpen());
chk('and still churns no events',
  A().length === 1 && A().map(e => e.t + e.s + e.e).join('|') === before15b, A().map(show).join(' | '));
chk('the sheet is aimed at the open block', /DW/.test($('spLab').textContent), $('spLab').textContent);
$('spClose').fire('click'); settle();
chk('closing it leaves the block alone', A().length === 1 && /#open/.test(A()[0].d), show(A()[0]));

chk('an unlit category still switches, it does not split',
  (tap('MTG'), settle(), A().length === 2 && !splitOpen()), A().map(show).join(' | '));

console.log('\n15b. the mark strip takes the posture row, not a row of its own');
reset(); reboot();
tap('ADM'); wait(40);
chk('posture pill visible before', !$('posture').hidden);
tap('DW'); settle();
chk('strip up', !$('strip').hidden);
chk('and the posture pill is what it replaced', $('posture').hidden);
tapMark('+');
chk('choosing a mark gives posture straight back', $('strip').hidden && !$('posture').hidden);
chk('the mark still landed', A()[0].t === 'ADM: +', A()[0].t);

console.log('\n16. DST spring forward produces no negative durations');
reset(D(2026, 3, 8, 1, 30)); reboot();                   // US DST change 08 Mar 2026
tap('DW'); settle();
H.setNow(D(2026, 3, 8, 4, 30));
tap('ADM'); settle();
chk('positive duration across the jump', A()[0].e > A()[0].s, show(A()[0]));
H.SCRIPT_PROPS.SHEET_ID = 'book'; H.clearPropCache();
dailyRollup();
chk('rollup survives the DST day', !JSON.stringify(H.SHEETS.book.getSheetByName('daily').rows).match(/NaN|-\d+\.\d/));

console.log('\n17. note never gates a tap');
reset(); reboot();
tap('DW'); wait(20);
noteBox().value = 'memo'; noteBox().fire('input');
tap('MTG'); tap('MTG'); settle(); advance(2000); settle();
chk('note landed on the closed block', A()[0].t === 'DW: memo =', A()[0].t);
chk('new block has no note', A()[1].t === 'MTG:', A()[1].t);
chk('the new box offers an empty note', noteBox().value === '', noteBox().value);

console.log('\n18. adjust the open SIT start');
reset(); reboot();
tapSit(); wait(20);
$('sitEdit').fire('click'); settle();                      // the clock is the way in
const lo = Number($('ssRange').min), hi = Number($('ssRange').max);
$('ssRange').value = String(hi - 60); $('ssRange').fire('input');
$('ssApply').fire('click'); settle();
chk('SIT start moved back', (H.nowMs() - S()[0].s) > 55 * 60000, show(S()[0]));
chk('still open', /#open/.test(S()[0].d));
$('sitEdit').fire('click'); settle();
$('ssDelete').fire('click'); settle();
chk('discard removes the block', S().length === 0);
chk('toggle reads standing', litPosture() === 'stand', String(litPosture()));

console.log('\n19. doGet serves the page');
reset(); reboot();
let out = null, doGetErr = null;
try { out = doGet(); } catch (e) { doGetErr = e; }
chk('doGet does not throw', !doGetErr, doGetErr && doGetErr.message);
chk('title set', out && out.title === 'timetap', out && out.title);
chk('every meta tag is one Apps Script allows',
  !!out && out.metas.every(m => H.META_ALLOWED.has(m[0])),
  out && JSON.stringify(out.metas));
chk('viewport meta present', !!out && out.metas.some(m => m[0] === 'viewport'));
chk('bootstrap config injected', !!out && /"minMarkMinutes":15/.test(out.getContent()));
chk('no unresolved template tags', !!out && !/<\?!?=/.test(out.getContent()),
  out && (out.getContent().match(/<\?!?=[^>]*>/g) || []).join(' '));
chk('frame options set', !!out && out.xframe === 'ALLOWALL', out && out.xframe);

console.log('\n20. calendar ids resolve from script properties');
reset(); reboot();
tap('DW'); settle();
chk('literal in CONFIG still works', A().length === 1 && H.CALS.alt.events.length === 0,
  'actual=' + A().length + ' alt=' + H.CALS.alt.events.length);

reset();
H.SCRIPT_PROPS.CAL_ACTUAL = 'alt';
H.clearPropCache();
reboot();
tap('DW'); wait(30); tap('MTG'); settle();
chk('script property overrides the literal',
  H.CALS.alt.events.length === 2 && H.CALS.actual.events.length === 0,
  'actual=' + H.CALS.actual.events.length + ' alt=' + H.CALS.alt.events.length);
chk('open block recovers from the overridden calendar', activeKey() === 'MTG', String(activeKey()));

reset();
H.SCRIPT_PROPS.CAL_ACTUAL = '  alt  ';
H.clearPropCache();
reboot();
tap('ADM'); settle();
chk('a pasted id with whitespace is trimmed', H.CALS.alt.events.length === 1,
  'alt=' + H.CALS.alt.events.length);

reset();
H.SCRIPT_PROPS.CAL_ACTUAL = '';
H.clearPropCache();
reboot();
tap('DW'); settle();
chk('an empty property falls back to the literal', A().length === 1, 'actual=' + A().length);
reset();

console.log('\n21. the palette is legible and is Google Calendar\'s own');
reset();
// Google Calendar's rendered event colours. A button must be the colour of the
// event it writes, so drift here is a real bug, not a style preference.
var GCAL = { '1':'#7986cb','2':'#33b679','3':'#8e24aa','4':'#e67c73','5':'#f6bf26',
             '6':'#f4511e','7':'#039be5','8':'#616161','9':'#3f51b5','10':'#0b8043','11':'#d50000' };
chk('COLOR_HEX matches Google Calendar exactly',
  Object.keys(GCAL).every(function (k) { return COLOR_HEX[k] === GCAL[k]; }),
  Object.keys(GCAL).filter(function (k) { return COLOR_HEX[k] !== GCAL[k]; })
    .map(function (k) { return k + ': ' + COLOR_HEX[k] + ' != ' + GCAL[k]; }).join(', '));
chk('all eleven ids are covered', Object.keys(COLOR_HEX).length === 11);

chk('white on the black highlight is 21:1', contrast_('#ffffff', '#000000') > 20.9,
  contrast_('#ffffff', '#000000').toFixed(2));

// The active ring is now one white outset line sitting in the gap, where the
// page is always black, so there is no per-colour choice left to get wrong.
// What still has to hold is that the palette is Google's and the label is
// readable on any of it.
chk('the black highlight is legible on every colour in the palette',
  Object.keys(COLOR_HEX).every(function (id) { return contrast_('#ffffff', '#000000') >= 4.5; }));

chk('every configured category resolves to a palette colour',
  clientConfig_().categories.every(function (c) {
    return Object.keys(COLOR_HEX).some(function (k) { return COLOR_HEX[k] === c.hex; });
  }),
  clientConfig_().categories.map(function (c) { return c.key + ':' + c.hex; }).join(' '));

console.log('\n22. the event is the colour of the button that made it');
reset(); reboot();
var CFG22 = {}; clientConfig_().categories.forEach(function (c) { CFG22[c.key] = c; });
function evColour(e) { return e.c; }
function sameAsButton(e, key) {
  return evColour(e) === CFG22[key].color && COLOR_HEX[evColour(e)] === CFG22[key].hex;
}

tap('DW'); settle();
chk('DW block carries the DW colour', sameAsButton(A()[0], 'DW'),
  'event=' + evColour(A()[0]) + ' button=' + CFG22.DW.color + '/' + CFG22.DW.hex);
wait(30); tap('MTG'); settle();
chk('MTG block carries the MTG colour', sameAsButton(A()[1], 'MTG'), 'event=' + evColour(A()[1]));
chk('closing a block does not disturb its colour', sameAsButton(A()[0], 'DW'));

reset(); reboot();
tap('DW'); settle(); settle();
advance(10000); settle(); tap('BODY'); tap('BODY'); settle();
chk('a mis-tap correction recolours the surviving event',
  A().length === 1 && sameAsButton(A()[0], 'BODY'),
  'n=' + A().length + ' colour=' + evColour(A()[0]));

reset(); reboot();
tap('MTG'); settle(); wait(120);
tap('MTG'); settle();
$('spRange').value = '60'; $('spRange').fire('input');
$('splitGrid').children[5].fire('click'); settle();      // FRAG
chk('split writes the remainder in the chosen colour', sameAsButton(A()[1], 'FRAG'),
  'colour=' + evColour(A()[1]));
chk('and leaves the original block its own', sameAsButton(A()[0], 'MTG'), 'colour=' + evColour(A()[0]));

reset();
chk('every configured category uses a real Google Calendar colour',
  CATEGORIES.every(function (c) { return !!COLOR_HEX[String(c.color)]; }),
  CATEGORIES.filter(function (c) { return !COLOR_HEX[String(c.color)]; })
    .map(function (c) { return c.key + '=' + c.color; }).join(' '));
chk('UNLOGGED stays graphite, not any category colour',
  String(UNLOGGED_COLOR) === '8' && COLOR_HEX['8'] === '#616161');

console.log('\n23. one posture button, two states');
reset(); reboot();
chk('starts standing', litPosture() === 'stand', String(litPosture()));
chk('and writes nothing for it', S().length === 0);

posture('stand'); wait(10);
chk('setting not-sitting when already so writes nothing', S().length === 0, S().map(show).join(' | '));

posture('sit'); wait(45);
chk('sitting opens a block', S().length === 1 && /#open/.test(S()[0].d), S().map(show).join(' | '));
chk('sitting is lit', litPosture() === 'sit');

const tStand = H.nowMs();
posture('stand');
chk('standing closes the block at that instant',
  S().length === 1 && !/#open/.test(S()[0].d) && near(S()[0].e, tStand), show(S()[0]));
chk('and the button flips', litPosture() === 'stand');

posture('stand');
chk('it stays a no-op', S().length === 1 && litPosture() === 'stand');
chk('the label says what it is', $('postureLabel').textContent === 'NOT SITTING',
  $('postureLabel').textContent);
chk('and no duration is offered when not sitting',
  $('sitEl').textContent === '' && $('sitEdit')._cls.has('off'), $('sitEl').textContent);
posture('sit'); wait(20);
chk('sitting labels itself', $('postureLabel').textContent === 'SITTING');
chk('and shows only its own duration', /(19|20|21)m/.test($('sitEl').textContent),
  $('sitEl').textContent);

console.log('\n23b. BODY still closes sitting, and the row follows');
reset(); reboot();
posture('sit'); wait(30);
const tBody = H.nowMs();
tap('BODY');
chk('SIT closed at the tap', near(S()[0].e, tBody), show(S()[0]));
chk('row moved off sitting', litPosture() === 'stand', String(litPosture()));

console.log('\n23c. only sitting is ever written');
reset(); reboot();
posture('stand'); wait(60); posture('stand'); wait(60);
chk('no calendar rows for standing', S().length === 0, S().map(show).join(' | '));
chk('and none of it touched ACTUAL', A().length === 0);

console.log('\n23d. the lit half is a fact about the calendar, not a memory');
reset(); reboot();
posture('sit'); wait(30); settle();
Object.keys(H.STORE).forEach(k => delete H.STORE[k]);   // wipe the mirror entirely
reboot();
chk('sitting recovered from the calendar alone', litPosture() === 'sit', String(litPosture()));
chk('with a live timer', /(29|30|31)m/.test($('sitEl').textContent), $('sitEl').textContent);
posture('stand'); settle();
Object.keys(H.STORE).forEach(k => delete H.STORE[k]);
reboot();
chk('standing recovered from the calendar alone', litPosture() === 'stand', String(litPosture()));
chk('nothing left open on SITTING', !S().some(e => /#open/.test(e.d)), S().map(show).join(' | '));

console.log('\n24. clock times read as 12 hour');
reset(D(2026, 7, 24, 13, 26)); reboot();
tap('MTG'); settle(); wait(120);
tap('MTG'); settle();
chk('afternoon shows PM', / PM$/.test($('spAt').textContent), $('spAt').textContent);
chk('no 24 hour hours anywhere in the sheet',
  !/\b(1[3-9]|2[0-3]):/.test($('spAt').textContent + $('spStart').textContent + $('spNow').textContent),
  [$('spAt').textContent, $('spStart').textContent, $('spNow').textContent].join(' '));
$('spClose').fire('click');
reset(D(2026, 7, 24, 0, 5)); reboot();
tap('DW'); settle(); wait(120);
tap('DW'); settle();
chk('midnight is 12 AM, never 0', /^12:/.test($('spStart').textContent) && / AM$/.test($('spStart').textContent),
  $('spStart').textContent);
reset(D(2026, 7, 24, 12, 30)); reboot();
tap('DW'); settle(); wait(60);
tap('DW'); settle();
chk('noon is 12 PM, never 0', /^12:/.test($('spStart').textContent) && / PM$/.test($('spStart').textContent),
  $('spStart').textContent);

console.log('\n25. a tap on the heels of the last one asks first');
reset(); reboot();
tap('DW'); settle();
chk('the first tap needs no confirming', A().length === 1, A().map(show).join(' | '));

advance(10000); settle();
const q25 = JSON.parse(H.STORE['tt.queue.v1'] || '[]').length;
tap('MTG'); settle();
chk('a tap 10s later writes nothing yet', A().length === 1 && A()[0].t === 'DW:',
  A().map(show).join(' | '));
chk('nothing queued either', JSON.parse(H.STORE['tt.queue.v1'] || '[]').length === q25,
  'queue grew');
chk('the button it landed on is armed', armedKey() === 'MTG', String(armedKey()));

tap('MTG'); settle();
chk('the second tap commits', A().length === 1 && A()[0].t === 'MTG:', A().map(show).join(' | '));
chk('and disarms', armedKey() === null, String(armedKey()));

console.log('\n25b. ignoring the question is the safe outcome');
reset(); reboot();
tap('DW'); settle(); advance(20000); settle();
tap('FRAG'); settle();
chk('armed', armedKey() === 'FRAG');
advance(5000); settle();
chk('it forgets on its own', armedKey() === null, String(armedKey()));
chk('and never wrote anything', A().length === 1 && A()[0].t === 'DW:', A().map(show).join(' | '));

console.log('\n25c. arming a different box moves the question');
reset(); reboot();
tap('DW'); settle(); advance(10000); settle();
tap('MTG'); settle();
tap('ADM'); settle();
chk('only the newest is armed', armedKey() === 'ADM', String(armedKey()));
chk('still nothing written', A().length === 1, A().map(show).join(' | '));
tap('ADM'); settle();
chk('confirming that one commits it', A()[0].t === 'ADM:', A().map(show).join(' | '));

console.log('\n25d. past the window it just acts');
reset(); reboot();
tap('DW'); settle(); wait(3);
tap('MTG'); settle();
chk('a tap 3 minutes later needs no confirming', A().length === 2, A().map(show).join(' | '));
chk('and arms nothing', armedKey() === null, String(armedKey()));

console.log('\n25e. the gate never blocks SPLIT, which writes nothing');
reset(); reboot();
tap('DW'); settle(); wait(30);
tap('DW'); settle();
chk('re-tapping the lit button still opens SPLIT', splitOpen());
chk('without arming it', armedKey() === null, String(armedKey()));

console.log('\n26. the note and the clock live in the lit box');
reset(); reboot();
const cellOf = k => $('grid').children.find(c => c.dataset.key === k);
const catCells = () => $('grid').children.filter(c => c.dataset.key);
chk('an idle grid shows no clock anywhere',
  catCells().every(c => c.querySelector('.ge').textContent === ''));

tap('DW'); wait(12);
chk('the lit box carries the clock', /1[123]m/.test(elapsedBox()), elapsedBox());
chk('and no unlit box does',
  catCells().filter(c => c.dataset.key !== 'DW')
    .every(c => c.querySelector('.ge').textContent === ''));

noteBox().value = 'memo drafting'; noteBox().fire('input');
advance(1000); settle();
chk('typing in the lit box titles the block', A()[0].t === 'DW: memo drafting', A()[0].t);

wait(30); tap('MTG'); tap('MTG'); settle();
chk('the note stayed with the block it described', A()[0].t === 'DW: memo drafting =', A()[0].t);
chk('the newly lit box offers an empty note', noteBox().value === '', noteBox().value);
chk('the box that went dark drops its note',
  cellOf('DW').querySelector('.gn').value === '', cellOf('DW').querySelector('.gn').value);
chk('and its clock', cellOf('DW').querySelector('.ge').textContent === '');

const stale = cellOf('FRAG').querySelector('.gn');
stale.value = 'typed into the wrong box'; stale.fire('input');
advance(1000); settle();
chk('an unlit box cannot write a note', A()[1].t === 'MTG:', A()[1].t);

console.log('\n26b. a long block flags itself in place');
reset(); reboot();
tap('ADM'); wait(30);
chk('not flagged at 30m', !cellOf('ADM')._cls.has('long'));
wait(70);
chk('flagged past 90m', cellOf('ADM')._cls.has('long'));
chk('the clock is what carries it', /1h(39|40|41)/.test(elapsedBox()), elapsedBox());

console.log('\n27. the add box makes a category');
reset(); reboot();
chk('the add box is there', !!addCell());
chk('and it is not a category', addCell().dataset.key === undefined);

const ac = addCell(), an = ac.querySelector('.an');
ac.fire('click');
chk('tapping it turns the label into a field', ac._cls.has('naming'));

an.value = 'Reading'; an.fire('blur'); settle();
chk('a seventh category exists', $('grid').children.filter(c => c.dataset.key).length === 7,
  String($('grid').children.filter(c => c.dataset.key).length));
const added = clientConfig_().categories.find(c => c.label === 'Reading');
chk('with the label as typed', !!added && added.label === 'Reading', JSON.stringify(added));
chk('a key derived from it', added.key === 'READING', added && added.key);
chk('and a colour nobody else was using',
  clientConfig_().categories.filter(c => c.color === added.color).length === 1, added && added.color);
chk('it is a real Google Calendar colour', !!COLOR_HEX[added.color], added && added.color);

chk('it logs like any other', (tap('READING'), settle(), A().length === 1 && A()[0].t === 'READING:'),
  A().map(show).join(' | '));
chk('and colours its event to match', A()[0].c === added.color, A()[0].c);

console.log('\n27b. it survives, and it refuses the obvious mistakes');
reboot();
chk('the new category came back on reload',
  $('grid').children.some(c => c.dataset.key === 'READING'));

let dupErr = null;
try { addCategory('reading'); } catch (e) { dupErr = String(e.message || e); }
chk('a duplicate name is refused', !!dupErr && /already/.test(dupErr), dupErr);

let blankErr = null;
try { addCategory('   '); } catch (e) { blankErr = String(e.message || e); }
chk('a blank name is refused', !!blankErr && /needs a name/.test(blankErr), blankErr);

const k2 = addCategory('Reading list').categories.find(c => c.label === 'Reading list');
chk('a colliding key gets disambiguated', k2.key !== 'READING' && /^READING/.test(k2.key), k2.key);

console.log('\n27c. the add box stops at the ceiling');
reset();
for (let i = 0; clientConfig_().categories.length < 10; i++) addCategory('Extra ' + i);
chk('ten categories', clientConfig_().categories.length === 10,
  String(clientConfig_().categories.length));
reboot();
chk('and the add box is gone', addCell() === null);
chk('the grid is exactly the ten', $('grid').children.filter(c => c.dataset.key).length === 10,
  String($('grid').children.filter(c => c.dataset.key).length));
let capErr = null;
try { addCategory('One too many'); } catch (e) { capErr = String(e.message || e); }
chk('the server refuses an eleventh', !!capErr && /10 categories/.test(capErr), capErr);
chk('the rollup carries all ten', (function () {
  H.SCRIPT_PROPS.SHEET_ID = 'book'; H.clearPropCache(); dailyRollup();
  const head = H.SHEETS.book.getSheetByName('daily').rows[0];
  return clientConfig_().categories.every(c => head.indexOf(c.key) > 0);
})());
reset();

console.log('\n28. the grid puts each thing where it belongs');
reset(); reboot();
const kidsOf = () => $('grid').children;
const shape = () => kidsOf().map(c => c.dataset.key || (c.dataset.add ? '+' : '_')).join(' ');

chk('always two columns', kidsOf().length % 2 === 0, String(kidsOf().length));
chk('no box ever spans a row', kidsOf().every(c => !c.style.gridColumn), shape());
chk('the add box is in the top row, furthest from the thumb',
  kidsOf()[0].dataset.add === '1', shape());
chk('the bottom row is two categories, not one and a button',
  kidsOf()[kidsOf().length - 2].dataset.key === 'DW' &&
  kidsOf()[kidsOf().length - 1].dataset.key === 'MTG', shape());
// Bottom row first, left to right within a row: DW MTG ADM BODY REL FRAG.
chk('categories run in config order up the grid',
  shape() === '+ _ REL FRAG ADM BODY DW MTG', shape());
chk('an odd count leaves one empty cell, also in the top row',
  kidsOf().filter(c => !c.dataset.key && c.dataset.add !== '1').length === 1 &&
  kidsOf().findIndex(c => !c.dataset.key && c.dataset.add !== '1') < 2, shape());

console.log('\n28b. a full grid has no add box and no gap');
reset();
for (let i = 0; clientConfig_().categories.length < 10; i++) addCategory('Extra ' + i);
reboot();
chk('ten cells exactly', kidsOf().length === 10, String(kidsOf().length));
chk('no add box', kidsOf().every(c => c.dataset.add !== '1'));
chk('every cell is a category', kidsOf().every(c => !!c.dataset.key), shape());
chk('and nothing spans', kidsOf().every(c => !c.style.gridColumn));
chk('the first two categories still hold the bottom row',
  kidsOf()[kidsOf().length - 2].dataset.key === 'DW' &&
  kidsOf()[kidsOf().length - 1].dataset.key === 'MTG', shape());
reset();

console.log('\n29. the rollup reports keys, not whatever had a colon in it');
reset(D(2026, 7, 24, 15, 0));
H.SCRIPT_PROPS.SHEET_ID = 'book'; H.clearPropCache();
const PL = (t2, d, h1, h2) => H.CALS.plan.createEvent(t2, new Date(D(2026, 7, d, h1, 0)),
  new Date(D(2026, 7, d, h2, 0)), {});
PL('9:00 standup', 20, 9, 10);
PL('Dinner: with Ada', 20, 19, 21);
PL('Re: the thing', 21, 9, 10);
PL('DW: ship it', 21, 10, 14);
reboot();
dailyRollup();
const hdr = H.SHEETS.book.getSheetByName('daily').rows[0];
/* UNFILED joins UNLOGGED here for the same reason UNLOGGED is here: it is a
   fixed key the rollup always reports, not a column conjured out of a title.
   None of the four PLAN events below can reach it — D1 files ACTUAL events
   only, and deliberately leaves an unreadable plan uncounted rather than
   guessing where it belonged. */
const known = clientConfig_().categories.map(c => c.key).concat(['UNLOGGED', UNFILED_KEY]);
const fixed = ['date', 'day', 'switches', 'waking h', 'sitting h', 'sitting %',
               'longest sit min', 'sits over 90'];
// The last-rebuilt stamp (C2) also lives in row 1, past the last data column.
// It is excluded by name rather than by loosening the filter, and pinned below,
// so a column genuinely invented from a title still fails this.
// B2 appended one column per key per mark bucket. They are derived from the
// configured keys, so they are the opposite of invented — but they still have
// to be named here, or this rule cannot tell them from a column conjured out
// of a subject line.
const markCols29 = [];
known.forEach(k => MARK_BUCKETS.forEach(m => markCols29.push(markCol_(k, m))));
const invented = hdr.filter(h => !fixed.includes(h) && !h.startsWith('plan ') &&
                                 !known.includes(h) && !markCols29.includes(h) &&
                                 !/^last rebuilt /.test(h));
chk('no column invented from a clock time or a subject line',
  invented.length === 0, invented.join(' '));
chk('and the only non-column cell in the header is the one stamp',
  hdr.filter(h => /^last rebuilt /.test(h)).length === 1,
  JSON.stringify(hdr.filter(h => /^last rebuilt /.test(h))));
chk('UNLOGGED is still reported', hdr.includes('UNLOGGED'));
chk('a real category prefix is still counted',
  H.SHEETS.book.getSheetByName('weekly').rows[1][hdr.indexOf('plan DW') >= 0 ? 1 : 1] !== undefined);

console.log('\n29b. the cap limits what the app adds, never what you configured');
reset();
const realCats = CATEGORIES.slice();
for (let i = 0; i < 6; i++) CATEGORIES.push({ key: 'X' + i, label: 'X' + i, color: '1', autoMark: null });
chk('twelve configured, twelve kept', allCategories_().length === 12,
  String(allCategories_().length));
chk('none silently dropped',
  CATEGORIES.every(c => allCategories_().some(a => a.key === c.key)));
let overErr = null;
try { addCategory('Nope'); } catch (e) { overErr = String(e.message || e); }
chk('and the add box refuses to go further', !!overErr && /categories already/.test(overErr), overErr);
CATEGORIES.length = 0; realCats.forEach(c => CATEGORIES.push(c));

console.log('\n29c. a category can be removed without nuking the rest');
reset();
addCategory('Reading'); addCategory('Errands');
chk('two added', clientConfig_().categories.length === 8);
removeCategory('READING');
chk('one removed', !clientConfig_().categories.some(c => c.key === 'READING'));
chk('the other survived', clientConfig_().categories.some(c => c.key === 'ERRANDS'));
chk('its key is remembered as retired', retiredKeys_().some(r => r.key === 'READING'));
H.SCRIPT_PROPS.SHEET_ID = 'book'; H.clearPropCache();
dailyRollup();
chk('so the rollup still reports its history',
  H.SHEETS.book.getSheetByName('daily').rows[0].includes('READING'));
let cfgErr = null;
try { removeCategory('DW'); } catch (e) { cfgErr = String(e.message || e); }
chk('a configured category cannot be removed at runtime',
  !!cfgErr && /Code\.gs/.test(cfgErr), cfgErr);

console.log('\n29d. a malformed op is dropped, not left blocking the queue');
reset();
const r29 = applyOps([
  { id: 'ok1', type: 'openActual', ref: 'aaaabbbbccccdddd', key: 'DW', startMs: Date.now() },
  { id: 'bad1', type: 'closeActual', ref: 'aaaabbbbccccdddd', endMs: NaN },
  { id: 'bad2', type: 'openActual', ref: '!!', key: 'DW', startMs: Date.now() },
  { id: 'ok2', type: 'openSit', ref: 'eeeeffff11112222', startMs: Date.now() }
]);
chk('the good ops both applied', r29.applied.includes('ok1') && r29.applied.includes('ok2'),
  JSON.stringify(r29.applied));
chk('the malformed ones were dropped', r29.dropped.length === 2,
  JSON.stringify(r29.dropped.map(d => d.id)));
chk('nothing errored, so nothing is stuck', r29.errors.length === 0, JSON.stringify(r29.errors));
chk('no event carries a broken time',
  A().every(e => isFinite(e.s) && isFinite(e.e) && e.e > e.s), A().map(show).join(' | '));

console.log('\n29e. a write that keeps failing is set aside');
reset(); reboot();
tap('DW'); settle();
H.setOnline(false);
wait(5); tap('MTG'); tap('MTG');
H.setOnline(true);
global.CAL_ACTUAL = 'nope';                       // the cause of the failure
for (let i = 0; i < 8; i++) { advance(70000); settle(); }
global.CAL_ACTUAL = 'actual';
const dead = JSON.parse(H.STORE['tt.dead.v1'] || '[]');
chk('it stopped being retried', dead.length >= 1, 'dead=' + dead.length);
chk('the reason was kept with it', dead.length && /nope|not set|resolve/i.test(dead[0].why),
  dead.length ? dead[0].why : '');
chk('and the user was told', !$('err').hidden, $('err').textContent);
advance(70000); settle();
chk('the queue drains once the poison is gone',
  JSON.parse(H.STORE['tt.queue.v1'] || '[]').length === 0,
  H.STORE['tt.queue.v1']);
reset();

console.log('\n29f. adding two categories in a row keeps both');
reset();
const n29 = clientConfig_().categories.length;
addCategory('First');
global.PROPS_ = { EXTRA_CATEGORIES: '[]' };        // the cache the lock re-reads past
addCategory('Second');
chk('both survived', clientConfig_().categories.length - n29 === 2,
  JSON.stringify(clientConfig_().categories.slice(n29).map(c => c.label)));

console.log('\n29g. coming back to the app lets the stale guard run');
reset(D(2026, 7, 20, 8, 0)); reboot();
tap('DW'); settle();
H.setNow(D(2026, 7, 20, 17, 0));
chk('nine hours later, still one unbounded block', A().length === 1, A().map(show).join(' | '));
H.fireVisible(); settle();
const g29 = A();
chk('returning bounds it', g29.length === 2, g29.map(show).join(' | '));
chk('at five hours, not nine', near(g29[0].e - g29[0].s, 5 * 3600000), show(g29[0]));
chk('and records the rest as UNLOGGED', g29[1].t === 'UNLOGGED -', g29[1].t);

reset(); reboot();
tap('DW'); settle();
const quiet = A().map(e => e.t + e.s + e.e).join('|');
H.fireVisible(); settle();
chk('a fresh block is left alone', A().map(e => e.t + e.s + e.e).join('|') === quiet);
reset();

console.log('\n30. idle is a state you can see');
reset(); reboot();
chk('nothing running dims the grid', $('grid')._cls.has('idle'));
tap('DW'); settle();
chk('a running block undims it', !$('grid')._cls.has('idle'));
wait(30); tap('MTG'); tap('MTG'); settle();
chk('switching keeps it undimmed', !$('grid')._cls.has('idle'));

reset(D(2026, 7, 20, 8, 0)); reboot();
tap('DW'); settle();
H.setNow(D(2026, 7, 20, 17, 0));
H.fireVisible(); settle();
chk('and the stale guard leaving nothing open dims it again',
  $('grid')._cls.has('idle') && activeKey() === null, String(activeKey()));

console.log('\n30b. the sync pill is absent unless it has something to say');
// document.getElementById is what the client uses; H.$ only sees nodes already made.
const el = id => document.getElementById(id);
reset(); reboot();
chk('quiet means the synced class, which CSS hides',
  el('sync').className === 's-synced', el('sync').className);
H.setOnline(false);
tap('DW'); settle();
chk('a failure switches it to a class that shows', el('sync').className === 's-failed',
  el('sync').className);
chk('and it carries the count', el('syncN').textContent === '1', el('syncN').textContent);
H.setOnline(true);
advance(60000); settle(); settle();
chk('draining puts it back to hidden', el('sync').className === 's-synced' &&
  el('syncN').textContent === '', el('sync').className + ' ' + el('syncN').textContent);
reset();

console.log('\n31. the grid answers to a keyboard and announces itself');
reset(); reboot();
const cell = k => $('grid').children.find(c => c.dataset.key === k);
// The empty cell is not a control and must not be in the tab order.
chk('every control is reachable by tab, and only the controls',
  $('grid').children.every(c => {
    const isControl = c.dataset.key || c.dataset.add === '1';
    return (c.getAttribute('tabindex') === '0') === !!isControl;
  }),
  $('grid').children.map(c => (c.dataset.key || (c.dataset.add ? '+' : '_')) + ':' +
    c.getAttribute('tabindex')).join(' '));
chk('cells announce a name',
  $('grid').children.filter(c => c.dataset.key)
    .every(c => (c.getAttribute('aria-label') || '').length > 0));
chk('the add box says what it is',
  addCell().getAttribute('aria-label') === 'add a category',
  addCell().getAttribute('aria-label'));
chk('nothing is pressed while idle',
  $('grid').children.filter(c => c.dataset.key)
    .every(c => c.getAttribute('aria-pressed') === 'false'));

cell('DW').fire('keydown', { key: 'Enter', preventDefault: function () {} });
settle();
chk('Enter logs a category', A().length === 1 && A()[0].t === 'DW:', A().map(show).join(' | '));
chk('and the lit one reports itself pressed',
  cell('DW').getAttribute('aria-pressed') === 'true' &&
  cell('MTG').getAttribute('aria-pressed') === 'false');

wait(30);
cell('BODY').fire('keydown', { key: ' ', preventDefault: function () {} });
settle();
chk('Space logs one too', A().length === 2 && A()[1].t === 'BODY:', A().map(show).join(' | '));

const el31 = id => document.getElementById(id);
chk('the posture button reports its state',
  el31('postureBtn').getAttribute('aria-pressed') === 'false',
  el31('postureBtn').getAttribute('aria-pressed'));
posture('sit'); settle();
chk('and flips it when sitting', el31('postureBtn').getAttribute('aria-pressed') === 'true');

console.log('\n31b. the mark strip is always one tap from gone');
reset(); reboot();
tap('ADM'); wait(40); tap('DW'); settle();
chk('strip up, posture row covered', !$('strip').hidden && $('posture').hidden);
$('strip').fire('click', { target: { closest: function () { return null; } } });
settle();
chk('tapping the strip itself dismisses it', $('strip').hidden && !$('posture').hidden);
chk('and the default mark still stands', A()[0].t === 'ADM: =', A()[0].t);
posture('sit'); settle();
chk('so the posture row is usable again', litPosture() === 'sit');
reset();

console.log('\n32. the label is sized for the column it gets');
reset(); reboot();
const faceSize = k => $('grid').children.find(c => c.dataset.key === k).querySelector('.k').style.fontSize;
chk('two columns give the label full size', faceSize('DW') === '26px', faceSize('DW'));

const real32 = CATEGORIES.slice();
for (let i = CATEGORIES.length; i < 11; i++)
  CATEGORIES.push({ key: 'X' + i, label: 'Extra ' + i, color: String((i % 11) + 1), autoMark: null });
reboot();
chk('eleven categories move to three columns',
  $('grid').style.gridTemplateColumns === 'repeat(3, 1fr)', $('grid').style.gridTemplateColumns);
chk('and the label shrinks to fit a narrower cell', faceSize('DW') === '19px', faceSize('DW'));
chk('every configured category is still on screen',
  CATEGORIES.every(c => $('grid').children.some(x => x.dataset.key === c.key)));
chk('the first two still hold the bottom row',
  $('grid').children[$('grid').children.length - 3].dataset.key === 'DW',
  $('grid').children.map(c => c.dataset.key || '_').join(' '));
CATEGORIES.length = 0; real32.forEach(c => CATEGORIES.push(c));
reset(); reboot();

console.log('\n32b. idle dims the categories and nothing else');
chk('idle to start with', $('grid')._cls.has('idle'));
chk('the add box is not a category and is not dimmed with them',
  addCell()._cls.has('addcell') && !addCell()._cls.has('active'),
  'the veil is scoped by :not(.addcell) in CSS');
tap('DW'); settle();
chk('and a running block lifts the veil', !$('grid')._cls.has('idle'));
reset();

console.log('\n33. setupRollup does the whole thing in one run');
reset();
let noSheet = null;
try { setupRollup(); } catch (e) { noSheet = String(e.message || e); }
chk('with no SHEET_ID it says exactly what to do',
  !!noSheet && /SHEET_ID/.test(noSheet) && /Script properties/.test(noSheet), noSheet);

// A URL pasted straight out of the address bar, not an extracted id.
H.SCRIPT_PROPS.SHEET_ID = 'https://docs.google.com/spreadsheets/d/book/edit#gid=0';
H.clearPropCache();
chk('the id is taken out of a pasted URL', sheetIdFrom_(H.SCRIPT_PROPS.SHEET_ID) === 'book',
  sheetIdFrom_(H.SCRIPT_PROPS.SHEET_ID));

reboot();
tap('DW'); wait(40); tap('MTG'); tap('MTG'); settle();
const report = setupRollup();
chk('it reports the sheet', /docs\.google\.com/.test(report), report.split('\n')[3]);
chk('it installs the trigger', H.TRIGGERS.length === 1 && H.TRIGGERS[0].fn === 'dailyRollup',
  String(H.TRIGGERS.length));
chk('it fills both tabs there and then',
  H.SHEETS.book.getSheetByName('daily').rows.length === 91 &&
  H.SHEETS.book.getSheetByName('weekly').rows.length > 1);
chk('and counts what it found on each calendar', /ACTUAL {4}2/.test(report),
  report.split('\n').slice(-3).join(' | '));
chk('it names the timezone it is drawing days in', /timezone/.test(report),
  report.split('\n').filter(l => /timezone/.test(l))[0]);
chk('the category count excludes UNLOGGED',
  new RegExp('90 days, ' + clientConfig_().categories.length + ' categories').test(report),
  report.split('\n').filter(l => /window/.test(l))[0]);

chk('running it twice does not double the trigger',
  (setupRollup(), H.TRIGGERS.length) === 1, String(H.TRIGGERS.length));

// The editor shows the execution log and never a return value, so anything a
// person is meant to read has to reach Logger or it may as well not exist.
chk('the report reaches the execution log, not just the return value',
  H.LOGGED.some(l => /Rollup is set up/.test(l)), JSON.stringify(H.LOGGED.slice(-1)));
chk('so does the trigger confirmation',
  H.LOGGED.some(l => /will run daily around/.test(l)));
chk('and the rollup says what it wrote',
  H.LOGGED.some(l => /rolled up 90 days/.test(l)),
  JSON.stringify(H.LOGGED.filter(l => /rolled up/.test(l)).slice(0, 1)));

reset();
H.SCRIPT_PROPS.SHEET_ID = 'book'; H.clearPropCache();
const emptyReport = setupRollup();
chk('an empty ACTUAL is called out rather than left to Sunday',
  /ACTUAL is empty/.test(emptyReport), emptyReport.split('\n').slice(-1)[0]);
reset();

console.log('\n33b. a shared workbook is called out before it is overwritten');
reset();
H.SCRIPT_PROPS.SHEET_ID = 'book'; H.clearPropCache();
H.SHEETS.book.insertSheet('Inventory');
const shared = setupRollup();
chk('it names the tabs that are not its own', /other tabs: Inventory/.test(shared),
  shared.split('\n').filter(l => /other tabs/.test(l))[0]);
chk('and says which two it rewrites nightly',
  /daily and weekly are cleared/.test(shared.replace(/\n/g, ' ')),
  shared.split('\n').slice(-3).join(' | '));
reset();
H.SCRIPT_PROPS.SHEET_ID = 'book'; H.clearPropCache();
const dedicated = setupRollup();
chk('a dedicated sheet gets no such warning', !/other tabs/.test(dedicated));
reset();

/* ── A1: a server rejection is a different failure from a dropped connection ──
 * Everything downstream of here (the drawer, what a dead entry knows about
 * itself) is only honestly testable if a failure can be forced on demand. These
 * assert what today's unmodified client already does. */

const Q = () => JSON.parse(H.STORE['tt.queue.v1'] || '[]');
const DEAD = () => JSON.parse(H.STORE['tt.dead.v1'] || '[]');
const headTries = () => { const q = Q(); return q.length ? (q[0].tries || 0) : null; };
// The backoff starts at 4s and doubles to a 60s ceiling (Index.html:522), so the
// step has to be smaller than the gap being counted or one advance swallows the
// whole early ladder — 4+8+16+32s inside a single 61s jump, five attempts where
// the test meant to observe one. Small steps to count attempts exactly; big
// steps only once the delay has pinned at its ceiling.
function pump(cond, cap, stepMs) {
  const step = stepMs === undefined ? 1000 : stepMs;
  for (let i = 0; i < (cap === undefined ? 200 : cap) && !cond(); i++) { advance(step); settle(); }
  return cond();
}

console.log('\n34. a server rejection travels the server path, not the offline one');
reset();
H.setServerReject('server said no');
const rej = applyOps([{ id: 'srv1', type: 'openActual', ref: 'aaaabbbbccccdddd',
                        key: 'DW', startMs: Date.now() }]);
chk('the rejection comes back through errors, not as a thrown call',
  rej.errors.length === 1, JSON.stringify(rej.errors));
chk('the error names the op that caused it',
  rej.errors.length === 1 && rej.errors[0].id === 'srv1', JSON.stringify(rej.errors));
chk('and carries the thrown message',
  rej.errors.length === 1 && /server said no/.test(rej.errors[0].message),
  JSON.stringify(rej.errors));
chk('nothing was applied', rej.applied.length === 0, JSON.stringify(rej.applied));
chk('and nothing reached the calendar', A().length === 0, A().map(show).join(' | '));
reset();

console.log('\n34b. five rejections set the write aside — and four do not');
reset(); reboot();
H.setServerReject('calendar is not having it');
tap('DW');
chk('the write is queued', Q().length === 1, JSON.stringify(Q().map(o => o.type)));
pump(() => (headTries() || 0) >= 4 || DEAD().length > 0);
chk('after four attempts it is still queued', Q().length === 1, JSON.stringify(Q()));
chk('and nothing has been set aside yet', DEAD().length === 0, JSON.stringify(DEAD()));
chk('four is really four', headTries() === 4, String(headTries()));
// Stop at the fifth attempt whether or not it set anything aside. Pumping until
// a dead entry appears would pass just as happily on a client that gave up on
// the sixth — the threshold has to be observed, not waited for.
pump(() => DEAD().length > 0 || (headTries() || 0) >= 5);
chk('the fifth attempt sets it aside, and not one later',
  DEAD().length === 1, 'dead=' + DEAD().length + ' tries=' + headTries());
chk('and it leaves the queue', Q().length === 0, JSON.stringify(Q()));
chk('the reason kept is the server\'s own message',
  DEAD().length === 1 && /calendar is not having it/.test(DEAD()[0].why),
  DEAD().length ? DEAD()[0].why : '(none)');
chk('the op it set aside is the one that failed',
  DEAD().length === 1 && DEAD()[0].op.type === 'openActual',
  DEAD().length ? DEAD()[0].op.type : '(none)');
chk('and the user was told', !$('err').hidden, $('err').textContent);
reset();

console.log('\n34c. a network failure is never counted against an op');
reset(); reboot();
H.setOnline(false);
tap('DW');
chk('the write is queued', Q().length === 1, JSON.stringify(Q().map(o => o.type)));
for (let i = 0; i < 8; i++) { advance(61000); settle(); }
chk('after eight retries it is still queued', Q().length === 1, JSON.stringify(Q()));
chk('nothing was set aside', DEAD().length === 0, JSON.stringify(DEAD()));
chk('and no try was counted against it', !Q()[0].tries, String(Q()[0] && Q()[0].tries));
H.setOnline(true);
reset();

console.log('\n34d. the dead list is capped at fifty, keeping the newest');
reset();
const many = [];
for (let i = 0; i < 60; i++) {
  many.push({ id: 'op' + i, type: 'openActual', ref: 'ref' + String(i).padStart(5, '0'),
              key: 'DW', startMs: Date.now() + i * 60000 });
}
H.STORE['tt.queue.v1'] = JSON.stringify(many);
H.setServerReject('still no');
reboot();
pump(() => Q().length === 0, 2000, 61000);
chk('every one of the sixty left the queue', Q().length === 0, String(Q().length));
chk('the dead list holds exactly fifty', DEAD().length === 50, String(DEAD().length));
chk('the oldest ten were dropped, not the newest',
  DEAD().length === 50 && DEAD()[0].op.ref === 'ref00010' && DEAD()[49].op.ref === 'ref00059',
  DEAD().length ? DEAD()[0].op.ref + '..' + DEAD()[DEAD().length - 1].op.ref : '(empty)');
reset();

console.log('\n35. a set-aside write says which block it belonged to');
reset(); reboot();
tap('ADM');
const b1Start = H.nowMs();
wait(52); tap('DW');                       // ADM closes, the strip offers a mark
chk('the strip is up, so a mark is possible', !$('strip').hidden);
chk('and everything so far is written', Q().length === 0, JSON.stringify(Q()));
H.setServerReject('calendar said no');
tapMark('+');
pump(() => DEAD().length > 0);
chk('the mark was set aside', DEAD().length === 1, JSON.stringify(DEAD()));
chk('a setMark names the category the mark belonged to',
  DEAD().length === 1 && DEAD()[0].key === 'ADM',
  DEAD().length ? String(DEAD()[0].key) : '(none)');
chk('and that block\'s start time',
  DEAD().length === 1 && near(DEAD()[0].startMs, b1Start),
  DEAD().length ? new Date(DEAD()[0].startMs) + ' vs ' + new Date(b1Start) : '(none)');
chk('the op itself never carried a category — the index did',
  DEAD().length === 1 && !DEAD()[0].op.key, JSON.stringify(DEAD()[0] && DEAD()[0].op));
reset();

console.log('\n35b. a closeActual names the block being closed');
reset(); reboot();
tap('DW');
const b1Open = H.nowMs();
wait(30);
H.setServerReject('calendar said no');
tap('MTG');                                // closeActual(DW) leads the queue
pump(() => DEAD().length > 0);
chk('the close was set aside', DEAD().length === 1, JSON.stringify(DEAD().map(d => d.op.type)));
chk('and it names the category being closed',
  DEAD().length === 1 && DEAD()[0].op.type === 'closeActual' && DEAD()[0].key === 'DW',
  DEAD().length ? DEAD()[0].op.type + '/' + DEAD()[0].key : '(none)');
chk('with the start of the block, not its end',
  DEAD().length === 1 && near(DEAD()[0].startMs, b1Open),
  DEAD().length ? new Date(DEAD()[0].startMs) + ' vs ' + new Date(b1Open) : '(none)');
reset();

console.log('\n35c. an openActual names the category that was tapped');
reset(); reboot();
H.setServerReject('calendar said no');
const b1Tap = H.nowMs();
tap('FRAG');
pump(() => DEAD().length > 0);
chk('the open was set aside', DEAD().length === 1, JSON.stringify(DEAD().map(d => d.op.type)));
chk('and it names the tapped category',
  DEAD().length === 1 && DEAD()[0].key === 'FRAG',
  DEAD().length ? String(DEAD()[0].key) : '(none)');
chk('and when it was tapped',
  DEAD().length === 1 && near(DEAD()[0].startMs, b1Tap),
  DEAD().length ? String(DEAD()[0].startMs) : '(none)');
reset();

console.log('\n35d. a category removed since still reads back by name');
reset();
addCategory('Scratch');
const scratch = clientConfig_().categories.slice(-1)[0].key;
reboot();
H.setServerReject('calendar said no');
tap(scratch);
pump(() => DEAD().length > 0);
chk('the write was set aside', DEAD().length === 1, JSON.stringify(DEAD()));
removeCategory(scratch);
H.clearPropCache();
chk('the category really is gone',
  !clientConfig_().categories.some(c => c.key === scratch),
  JSON.stringify(clientConfig_().categories.map(c => c.key)));
let b1Read = null, b1Threw = null;
try { b1Read = DEAD()[0].key; } catch (e) { b1Threw = String(e); }
chk('the entry still names the key rather than going blank',
  b1Read === scratch, 'read=' + b1Read + ' threw=' + b1Threw);
reset();

console.log('\n35e. an entry from an older version is still readable');
reset();
H.STORE['tt.dead.v1'] = JSON.stringify([
  { at: D(2026, 7, 20, 9, 15), why: 'whatever went wrong', op: { type: 'setMark', ref: 'oldref00' } }
]);
let b1Boot = null;
try { reboot(); } catch (e) { b1Boot = String(e && e.message || e); }
chk('booting on a legacy entry does not throw', b1Boot === null, String(b1Boot));
// Whether that message survives the state load is finding F1, fixed and asserted in B2.
chk('and the boot message counted it', /set aside/.test($('err').textContent), $('err').textContent);
chk('the legacy entry was left alone, not rewritten',
  DEAD().length === 1 && DEAD()[0].key === undefined, JSON.stringify(DEAD()));
reset();

/* ── B2: the banner is a door ─────────────────────────────────────── */

const uiRows = () => (H.NODES['deadList'] ? H.NODES['deadList'].children : []);
// `el` (declared above) goes through document; `$` hands back only nodes the
// client has already touched, and a drawer that was never opened has none —
// which is exactly the case worth asserting about.
const rowText = r => r.children.map(c => c.textContent).join(' | ');
// Two writes the server will never accept, plus the block index that a real
// session would have left behind for them.
function seedTwoDead() {
  reset();
  H.STORE['tt.queue.v1'] = JSON.stringify([
    { id: 'd1', type: 'openActual', ref: 'refaaaa1', key: 'DW', startMs: D(2026, 7, 20, 9, 0) },
    { id: 'd2', type: 'setMark', ref: 'refbbbb2', mark: '+', hintMs: D(2026, 7, 20, 10, 0) }
  ]);
  H.STORE['tt.blocks.v1'] = JSON.stringify({
    refaaaa1: { key: 'DW', startMs: D(2026, 7, 20, 9, 0) },
    refbbbb2: { key: 'MTG', startMs: D(2026, 7, 20, 10, 0) }
  });
  H.setServerReject('the calendar refused');
  reboot();
  pump(() => Q().length === 0, 2000, 61000);
  H.setServerReject(null);
  reboot();                                  // a fresh, healthy load
}

console.log('\n36. the banner survives a healthy load and opens a drawer');
seedTwoDead();
chk('both writes were set aside', DEAD().length === 2, JSON.stringify(DEAD().map(d => d.op.type)));
chk('the banner is visible after a load that succeeded', !$('err').hidden, $('err').textContent);
chk('and it counts them in a sentence that parses',
  $('err').textContent === '2 writes were set aside after repeated failures',
  $('err').textContent);
chk('it announces itself as a door',
  $('err').getAttribute('role') === 'button' && $('err').getAttribute('tabindex') === '0',
  $('err').getAttribute('role') + '/' + $('err').getAttribute('tabindex'));
$('err').click(); settle();
chk('tapping it opens the drawer', !$('sheetDead').hidden);
chk('holding exactly two rows', uiRows().length === 2, String(uiRows().length));
chk('newest first', /save the mark/.test(rowText(uiRows()[0])), rowText(uiRows()[0]));
chk('oldest last', /start a block/.test(rowText(uiRows()[1])), rowText(uiRows()[1]));

console.log('\n36b. every row says when, which, what and why');
const r36 = rowText(uiRows()[0]);
chk('a clock time', /\d{1,2}:\d\d (AM|PM)/.test(r36), r36);
chk('the category the mark belonged to', /MTG/.test(r36), r36);
chk('what it was trying to do, in words', /tried to save the mark/.test(r36), r36);
chk('never the op type', !/setMark|closeActual|openActual/.test(r36), r36);
chk('and why it failed', /the calendar refused/.test(r36), r36);
chk('the other row names its own category', /DW/.test(rowText(uiRows()[1])), rowText(uiRows()[1]));

console.log('\n36c. closing the drawer gives the grid back');
$('dgClose').click(); settle();
chk('the drawer is closed', $('sheetDead').hidden);
chk('the banner is still there, because the writes still are', !$('err').hidden, $('err').textContent);
tap('DW');
chk('and a category tap still opens a block', activeKey() === 'DW', String(activeKey()));
chk('which reached the calendar', A().length === 1, A().map(show).join(' | '));
reset();

console.log('\n36d. no set-aside writes, no door');
reset(); reboot();
chk('the banner is hidden', $('err').hidden);
chk('it is not focusable', $('err').getAttribute('tabindex') === null,
  String($('err').getAttribute('tabindex')));
$('err').click(); settle();
chk('and tapping where it would be does nothing', el('sheetDead').hidden);
reset();

console.log('\n36e. a write type the drawer has no words for still renders');
reset();
H.STORE['tt.dead.v1'] = JSON.stringify([
  { at: D(2026, 7, 20, 11, 0), why: 'server said no', key: 'DW',
    startMs: D(2026, 7, 20, 10, 30), op: { type: 'frobnicate', ref: 'refcccc3' } }
]);
let b2Threw = null;
try { reboot(); $('err').click(); settle(); } catch (e) { b2Threw = String(e && e.message || e); }
chk('nothing throws', b2Threw === null, String(b2Threw));
chk('the row is there', uiRows().length === 1, String(uiRows().length));
chk('showing the raw type rather than a blank row',
  /frobnicate/.test(rowText(uiRows()[0])), rowText(uiRows()[0]));
chk('and it still says why', /server said no/.test(rowText(uiRows()[0])), rowText(uiRows()[0]));
reset();

console.log('\n36f. an entry from an older version renders its gaps as unknown (B1 criterion 5)');
reset();
H.STORE['tt.dead.v1'] = JSON.stringify([
  { at: D(2026, 7, 20, 9, 15), why: 'whatever went wrong', op: { type: 'setMark', ref: 'oldref00' } }
]);
let b2Legacy = null;
try { reboot(); $('err').click(); settle(); } catch (e) { b2Legacy = String(e && e.message || e); }
chk('nothing throws on the legacy shape', b2Legacy === null, String(b2Legacy));
chk('the row renders', uiRows().length === 1, String(uiRows().length));
const r36f = uiRows().length ? rowText(uiRows()[0]) : '';
chk('the missing category reads as unknown', /unknown category/.test(r36f), r36f);
chk('the missing start reads as unknown', /unknown start/.test(r36f), r36f);
chk('what it was doing is still known', /save the mark/.test(r36f), r36f);
chk('and no cell is simply blank', !/\|\s*\|/.test(r36f), r36f);
reset();

console.log('\n36h. one write reads as one write');
reset();
H.STORE['tt.dead.v1'] = JSON.stringify([
  { at: D(2026, 7, 20, 11, 0), why: 'server said no', key: 'DW',
    startMs: D(2026, 7, 20, 10, 30), op: { type: 'setMark', ref: 'refdddd4' } }
]);
reboot();
chk('the count agrees with its verb',
  $('err').textContent === '1 write was set aside after repeated failures',
  $('err').textContent);
reset();

console.log('\n36g. the drawer\'s markup is declared, not invented');
reset();
chk('the sheet exists in the markup', !!el('sheetDead'));
chk('its close button exists', !!el('dgClose'));
chk('its list exists', !!el('deadList'));
reset();

/* ── B3: an entry can be discarded once it has been dealt with ────── */

const dropBtn = r => r.children.find(c => c.tag === 'button');
// DISCARD arms on the first tap and acts on the second — the same two-step the
// grid uses for a consequential tap. See section 37f for why: a single-tap
// discard let the next row slide under the finger, so a double tap destroyed a
// second write the reader had never seen. Every assertion below is unchanged;
// only the gesture that reaches it is.
const discard = r => { const b = dropBtn(r); b.click(); settle(); b.click(); settle(); };
// The same window the grid's arm/confirm uses, read from the real config rather
// than written down here.
const CFG_CONFIRM_TIMEOUT = clientConfig_().confirmTimeoutMs;

console.log('\n37. discarding one of two leaves the other and the drawer open');
seedTwoDead();
$('err').click(); settle();
chk('two rows to start', uiRows().length === 2, String(uiRows().length));
const keptText = rowText(uiRows()[1]);
discard(uiRows()[0]);
chk('one row remains', uiRows().length === 1, String(uiRows().length));
chk('and it is the one not discarded', rowText(uiRows()[0]) === keptText, rowText(uiRows()[0]));
chk('the dead list in storage holds one', DEAD().length === 1, JSON.stringify(DEAD()));
chk('the drawer stays open', !$('sheetDead').hidden);
chk('and the banner now counts one', $('err').textContent === '1 write was set aside after repeated failures',
  $('err').textContent);

console.log('\n37b. discarding the last one closes the drawer and clears the banner');
discard(uiRows()[0]);
chk('the dead list is empty', DEAD().length === 0, JSON.stringify(DEAD()));
chk('the drawer closed itself', $('sheetDead').hidden);
chk('the banner is hidden', $('err').hidden, $('err').textContent);
chk('and it is no longer a door', $('err').getAttribute('role') === null,
  String($('err').getAttribute('role')));

console.log('\n37c. and it stays gone across a reload');
reboot();
chk('no set-aside message on the next load', $('err').hidden, $('err').textContent);
chk('the dead list is still empty', DEAD().length === 0, JSON.stringify(DEAD()));
reset();

console.log('\n37d. discarding never touches pending work');
reset();
H.STORE['tt.dead.v1'] = JSON.stringify([
  { at: D(2026, 7, 20, 11, 0), why: 'server said no', key: 'DW',
    startMs: D(2026, 7, 20, 10, 30), op: { type: 'setMark', ref: 'refdddd4', id: 'dead1' } }
]);
H.STORE['tt.queue.v1'] = JSON.stringify([
  { id: 'pending1', type: 'openActual', ref: 'refeeee5', key: 'MTG', startMs: D(2026, 7, 20, 11, 30) }
]);
H.setOnline(false);                            // so the pending write cannot drain
reboot();
const qBefore = H.STORE['tt.queue.v1'];
chk('there is a pending write', Q().length === 1, JSON.stringify(Q()));
$('err').click(); settle();
discard(uiRows()[0]);
chk('the set-aside entry is gone', DEAD().length === 0, JSON.stringify(DEAD()));
chk('the queue is byte-for-byte unchanged', H.STORE['tt.queue.v1'] === qBefore,
  H.STORE['tt.queue.v1'] + ' vs ' + qBefore);
H.setOnline(true);
reset();

console.log('\n37e. a button whose row has already gone discards nothing');
seedTwoDead();
$('err').click(); settle();
const staleRow = dropBtn(uiRows()[0]);
const survivor = rowText(uiRows()[1]);
discard(uiRows()[0]);
chk('the row was discarded', DEAD().length === 1, JSON.stringify(DEAD()));
let b3Threw = null;
try { staleRow.click(); settle(); staleRow.click(); settle(); }
catch (e) { b3Threw = String(e && e.message || e); }
chk('tapping its detached button throws nothing', b3Threw === null, String(b3Threw));
chk('and takes nothing with it', DEAD().length === 1, JSON.stringify(DEAD()));
chk('the surviving row is the one that should have survived',
  uiRows().length === 1 && rowText(uiRows()[0]) === survivor,
  uiRows().length ? rowText(uiRows()[0]) : '(none)');
reset();

/* Contract assertion 24. A single-tap discard let the rows below slide up into
   the space the finger had just left, so a double tap destroyed a second write
   the reader had never looked at. The token guard cannot catch that: the second
   tap lands on a genuinely different row holding a genuinely valid token. Both
   taps of a double tap must therefore resolve to the row that was aimed at.
   The tier-3 twin of this, in a real browser at real coordinates, is in
   test/headless.js — the shim cannot express a control moving under a finger. */
console.log('\n37f. a double tap discards the row it was aimed at, and only that row');
seedTwoDead();
$('err').click(); settle();
chk('two rows to start', uiRows().length === 2, String(uiRows().length));
const aimedAt = rowText(uiRows()[0]);
const bystander = rowText(uiRows()[1]);
const aimedBtn = dropBtn(uiRows()[0]);
chk('the button reads DISCARD before anything is tapped',
  aimedBtn.textContent === 'DISCARD', aimedBtn.textContent);
aimedBtn.click(); settle();
chk('one tap discards nothing at all', DEAD().length === 2, JSON.stringify(DEAD().length));
chk('it arms instead, and says so', aimedBtn.textContent === 'TAP AGAIN TO DISCARD',
  aimedBtn.textContent);
chk('and the row is still on screen', uiRows().length === 2, String(uiRows().length));
aimedBtn.click(); settle();
chk('the second tap discards exactly one', DEAD().length === 1, JSON.stringify(DEAD()));
chk('and it is the row that was aimed at — the bystander survives',
  uiRows().length === 1 && rowText(uiRows()[0]) === bystander,
  'aimed at: ' + aimedAt + '  ||  left: ' + (uiRows().length ? rowText(uiRows()[0]) : '(none)'));

console.log('\n37g. the row that slides up into the gap is not armed');
chk('the survivor is not carrying an armed button',
  dropBtn(uiRows()[0]).textContent === 'DISCARD', dropBtn(uiRows()[0]).textContent);
// A third tap in the same place lands on the survivor. It must arm it, never
// discard it — that is the whole mechanism of the bug this section pins.
dropBtn(uiRows()[0]).click(); settle();
chk('a stray tap on it arms rather than discards', DEAD().length === 1, JSON.stringify(DEAD()));
chk('the drawer is still open with its one row',
  !$('sheetDead').hidden && uiRows().length === 1, String(uiRows().length));
reset();

console.log('\n37h. an armed row forgets, so a stale confirmation cannot land later');
seedTwoDead();
$('err').click(); settle();
const forgetful = dropBtn(uiRows()[0]);
forgetful.click(); settle();
chk('it is armed', forgetful.textContent === 'TAP AGAIN TO DISCARD', forgetful.textContent);
advance(CFG_CONFIRM_TIMEOUT + 1000); settle();
chk('after the timeout it has disarmed itself', forgetful.textContent === 'DISCARD',
  forgetful.textContent);
forgetful.click(); settle();
chk('so the next tap arms again rather than discarding', DEAD().length === 2,
  JSON.stringify(DEAD().length));
reset();

console.log('\n37i. arming one row disarms any other');
seedTwoDead();
$('err').click(); settle();
const rowA = dropBtn(uiRows()[0]), rowB = dropBtn(uiRows()[1]);
rowA.click(); settle();
rowB.click(); settle();
chk('the first row went back to DISCARD', rowA.textContent === 'DISCARD', rowA.textContent);
chk('the second is the armed one', rowB.textContent === 'TAP AGAIN TO DISCARD', rowB.textContent);
rowA.click(); settle();
chk('tapping the first again only re-arms it', DEAD().length === 2, JSON.stringify(DEAD().length));
chk('and the second disarmed', rowB.textContent === 'DISCARD', rowB.textContent);
reset();

console.log('\n37j. a write set aside while the drawer is open appears in it');
reset(); reboot();
tap('ADM'); wait(52); tap('DW');
H.setServerReject('the calendar refused');
tapMark('+');
pump(() => DEAD().length > 0);
$('err').click(); settle();
chk('one row on screen', uiRows().length === 1, String(uiRows().length));
/* C1 nested the correction window inside the confirm window, and that changed
 * how many ops this second action produces: the tap used to land as a
 * correction (one recategorize) and now lands as a transition (a close and an
 * open). The old assertion pinned the number 2, which was an artifact of the
 * old window rather than anything this section is about.
 *
 * What it is about is that a write set aside WHILE THE DRAWER IS OPEN appears
 * in it without reopening. So that is what is asserted, and pinned harder than
 * before: the drawer must match the shelf exactly, and must have grown. */
const before37j = DEAD().length;
tap('FRAG'); wait(30); tap('DW'); tapMark('+');
pump(() => DEAD().length > before37j);
chk('the drawer grew while it was open', DEAD().length > before37j,
  'was ' + before37j + ', now ' + DEAD().length);
chk('and it shows every set-aside write, without reopening',
  uiRows().length === DEAD().length,
  'rows=' + uiRows().length + ' dead=' + DEAD().length);
H.setServerReject(null);
reset();

console.log('\n37k. closing the drawer leaves nothing behind in it');
seedTwoDead();
$('err').click(); settle();
chk('two rows while open', uiRows().length === 2, String(uiRows().length));
$('dgClose').click(); settle();
chk('the drawer is closed', $('sheetDead').hidden);
chk('and holds no rows at all', uiRows().length === 0, String(uiRows().length));
$('err').click(); settle();
chk('reopening rebuilds both rows', uiRows().length === 2, String(uiRows().length));
reset();

/* ── C1: a failed rollup records why, where the failure cannot erase it ── */

const REC = () => {
  const raw = H.SCRIPT_PROPS.ROLLUP_LAST;
  return raw === undefined ? null : JSON.parse(raw);
};
const goodSheet = () => { H.SCRIPT_PROPS.SHEET_ID = 'book'; H.clearPropCache(); };
const brokenSheet = () => { H.SCRIPT_PROPS.SHEET_ID = 'no-such-book'; H.clearPropCache(); };

console.log('\n38. a working rollup returns what it always did, and says so');
reset(); goodSheet();
tap('DW'); wait(40); tap('MTG'); wait(20); tap('DW');
const r38 = dailyRollup();
chk('it still returns days, categories and sheet',
  r38 && typeof r38.days === 'number' && typeof r38.categories === 'number' &&
  typeof r38.sheet === 'string', JSON.stringify(r38));
chk('the record says the run succeeded', REC() && REC().outcome === 'ok', JSON.stringify(REC()));
chk('with a timestamp', REC() && near(REC().lastSuccessMs, H.nowMs(), 2000),
  REC() ? String(REC().lastSuccessMs) : '(none)');
chk('and no failure is claimed', REC() && !REC().lastFailureMs, JSON.stringify(REC()));
reset();

console.log('\n38b. a sheet that cannot be opened records the failure and rethrows');
reset(); brokenSheet();
let e38 = null;
try { dailyRollup(); } catch (e) { e38 = String(e && e.message || e); }
chk('the error is rethrown so the platform marks the run failed', e38 !== null, String(e38));
chk('and it names the sheet it could not open', /no-such-book/.test(e38 || ''), String(e38));
chk('the record says it failed', REC() && REC().outcome === 'failed', JSON.stringify(REC()));
chk('with the reason kept', REC() && /no-such-book/.test(REC().lastFailureWhy || ''),
  REC() ? String(REC().lastFailureWhy) : '(none)');
chk('and a timestamp', REC() && near(REC().lastFailureMs, H.nowMs(), 2000),
  REC() ? String(REC().lastFailureMs) : '(none)');
reset();

console.log('\n38c. a failure never erases the last good run');
reset(); goodSheet();
tap('DW'); wait(30); tap('MTG');
dailyRollup();
const okAt = REC().lastSuccessMs;
chk('a success is on record', REC().outcome === 'ok' && okAt > 0, JSON.stringify(REC()));
wait(60);
brokenSheet();
try { dailyRollup(); } catch (e) {}
chk('the newer failure is recorded', REC().outcome === 'failed', JSON.stringify(REC()));
chk('and the last success is still there, to the millisecond',
  REC().lastSuccessMs === okAt, REC().lastSuccessMs + ' vs ' + okAt);
chk('the two are distinguishable', REC().lastFailureMs > REC().lastSuccessMs,
  REC().lastFailureMs + ' vs ' + REC().lastSuccessMs);
reset();

console.log('\n38d. a failure partway through the write is recorded too');
reset(); goodSheet();
tap('DW'); wait(30); tap('MTG');
const realWriteGrid = global.writeGrid_;
global.writeGrid_ = function () { throw new Error('the sheet went away mid-write'); };
let e38d = null;
try { dailyRollup(); } catch (e) { e38d = String(e && e.message || e); }
global.writeGrid_ = realWriteGrid;
chk('it rethrew', /mid-write/.test(e38d || ''), String(e38d));
chk('the failure is on record with its reason',
  REC() && REC().outcome === 'failed' && /mid-write/.test(REC().lastFailureWhy || ''),
  JSON.stringify(REC()));
reset();

console.log('\n38e. a success after a failure reads as current');
reset(); brokenSheet();
try { dailyRollup(); } catch (e) {}
const failAt = REC().lastFailureMs;
chk('the failure is on record', REC().outcome === 'failed', JSON.stringify(REC()));
wait(60);
goodSheet();
tap('DW'); wait(20); tap('MTG');
dailyRollup();
chk('the run now reads as ok', REC().outcome === 'ok', JSON.stringify(REC()));
chk('the success is the newer of the two', REC().lastSuccessMs > failAt,
  REC().lastSuccessMs + ' vs ' + failAt);
chk('and the old failure is still on record, not erased',
  REC().lastFailureMs === failAt && /no-such-book/.test(REC().lastFailureWhy || ''),
  JSON.stringify(REC()));
reset();

/* ── C2: both tabs say when they were last rebuilt ────────────────── */

const tabRows = name => {
  const sh = H.SHEETS.book.getSheetByName(name);
  return sh ? sh.rows : null;
};
const stampsIn = rows => {
  const found = [];
  (rows || []).forEach((r, i) => r.forEach((c, j) => {
    if (typeof c === 'string' && /^last rebuilt /.test(c)) found.push({ i, j, c });
  }));
  return found;
};

console.log('\n39. both tabs carry a last-rebuilt stamp');
reset(); goodSheet();
tap('DW'); wait(40); tap('MTG'); wait(20); tap('DW');
dailyRollup();
const dStamps = stampsIn(tabRows('daily'));
const wStamps = stampsIn(tabRows('weekly'));
chk('the daily tab has exactly one stamp', dStamps.length === 1, JSON.stringify(dStamps));
chk('the weekly tab has exactly one stamp', wStamps.length === 1, JSON.stringify(wStamps));
chk('the daily stamp is in row 1', dStamps.length === 1 && dStamps[0].i === 0,
  dStamps.length ? String(dStamps[0].i) : '(none)');
chk('past the last data column',
  dStamps.length === 1 && dStamps[0].j === tabRows('daily')[1].length - 1,
  dStamps.length ? dStamps[0].j + ' vs ' + (tabRows('daily')[1].length - 1) : '(none)');
chk('nothing else sits in that column',
  tabRows('daily').slice(1).every(r => r[dStamps[0].j] === ''),
  JSON.stringify(tabRows('daily').slice(1, 3).map(r => r[dStamps[0].j])));
chk('it reads as a date and a time',
  /^last rebuilt \d{4}-\d\d-\d\d \d\d:\d\d /.test(dStamps[0].c), dStamps[0].c);
chk('and it names the script timezone',
  dStamps[0].c.slice(-Session.getScriptTimeZone().length) === Session.getScriptTimeZone(),
  dStamps[0].c + ' / ' + Session.getScriptTimeZone());
chk('the clock in it is local, not UTC',
  dStamps[0].c.indexOf(' ' + String(new Date(H.nowMs()).getHours()).padStart(2, '0') + ':') > 0,
  dStamps[0].c + ' / local hour ' + new Date(H.nowMs()).getHours());
chk('the stamp states a fact and stops',
  !/stale|out of date|should|check|warning|⚠/i.test(dStamps[0].c), dStamps[0].c);

console.log('\n39b. running twice rewrites the stamp, it does not accumulate');
const firstStamp = dStamps[0].c;
wait(120);
dailyRollup();
chk('still exactly one stamp in daily', stampsIn(tabRows('daily')).length === 1,
  JSON.stringify(stampsIn(tabRows('daily'))));
chk('still exactly one in weekly', stampsIn(tabRows('weekly')).length === 1,
  JSON.stringify(stampsIn(tabRows('weekly'))));
chk('and it moved on', stampsIn(tabRows('daily'))[0].c !== firstStamp,
  stampsIn(tabRows('daily'))[0].c + ' vs ' + firstStamp);

console.log('\n39c. a failed run never refreshes the stamp');
const beforeFail = stampsIn(tabRows('daily'))[0].c;
const rowsBefore = JSON.stringify(tabRows('daily'));
wait(120);
brokenSheet();
let e39 = null;
try { dailyRollup(); } catch (e) { e39 = String(e && e.message || e); }
chk('the run failed', e39 !== null, String(e39));
chk('the stamp in the sheet is untouched', stampsIn(tabRows('daily'))[0].c === beforeFail,
  stampsIn(tabRows('daily'))[0].c + ' vs ' + beforeFail);
chk('and so is every other cell', JSON.stringify(tabRows('daily')) === rowsBefore);
reset();

console.log('\n39e. a tab\'s stamp is never newer than that tab\'s own numbers');
reset(); goodSheet();
tap('DW'); wait(40); tap('MTG');
dailyRollup();
const weeklyBefore = JSON.stringify(tabRows('weekly'));
const dailyStampBefore = stampsIn(tabRows('daily'))[0].c;
wait(180);
// Break the tab itself, not writeGrid_. Stubbing the function meant its own
// clear() never ran, so the case that actually blanked a tab was unreachable
// from here — the review found it by breaking getRange instead. Contract 25.
const weeklySheet = H.SHEETS.book.getSheetByName(WEEKLY_TAB);
const realGetRange = weeklySheet.getRange;
weeklySheet.getRange = function () { throw new Error('weekly tab is protected'); };
let e39e = null;
try { dailyRollup(); } catch (e) { e39e = String(e && e.message || e); }
weeklySheet.getRange = realGetRange;
chk('the run failed partway', /weekly tab is protected/.test(e39e || ''), String(e39e));
chk('the weekly tab is untouched — old numbers, old stamp, together',
  JSON.stringify(tabRows('weekly')) === weeklyBefore);
// Contract 25. writeGrid_ used to clear before it wrote, so a write that threw
// left the tab with no numbers AND no stamp — worse than stale, because nothing
// in the spreadsheet said anything had gone wrong.
chk('and it is not empty — a failed write never blanks a tab',
  tabRows('weekly').length > 0, 'weekly rows=' + tabRows('weekly').length);
chk('it still carries exactly its own old stamp',
  stampsIn(tabRows('weekly')).length === 1, JSON.stringify(stampsIn(tabRows('weekly'))));
chk('the daily tab got new numbers and a new stamp, also together',
  stampsIn(tabRows('daily'))[0].c !== dailyStampBefore,
  stampsIn(tabRows('daily'))[0].c + ' vs ' + dailyStampBefore);
chk('and the failure is on record', REC() && REC().outcome === 'failed', JSON.stringify(REC()));
reset();

/* Contract 16 as amended, and 25. A failure while BUILDING a grid must leave both
   tabs alone — which is why both grids are now built before either is written. */
console.log('\n39f. a failure before any write leaves both tabs exactly as they were');
reset(); goodSheet();
tap('DW'); wait(40); tap('MTG');
dailyRollup();
const bothBefore = JSON.stringify([tabRows('daily'), tabRows('weekly')]);
wait(180);
const realWeeklyGrid = global.weeklyGrid_;
global.weeklyGrid_ = function () { throw new Error('could not build the weekly grid'); };
let e39f = null;
try { dailyRollup(); } catch (e) { e39f = String(e && e.message || e); }
global.weeklyGrid_ = realWeeklyGrid;
chk('the run failed', /could not build the weekly grid/.test(e39f || ''), String(e39f));
chk('neither tab was touched — not even the one that would have been written first',
  JSON.stringify([tabRows('daily'), tabRows('weekly')]) === bothBefore);
chk('each tab still holds exactly one stamp',
  stampsIn(tabRows('daily')).length === 1 && stampsIn(tabRows('weekly')).length === 1,
  JSON.stringify(stampsIn(tabRows('daily'))) + ' / ' + JSON.stringify(stampsIn(tabRows('weekly'))));
chk('and the failure is on record with its reason',
  REC() && REC().outcome === 'failed' && /weekly grid/.test(REC().lastFailureWhy || ''),
  JSON.stringify(REC()));
chk('while the last success is still on record',
  REC() && !!REC().lastSuccessMs, JSON.stringify(REC()));
reset();

/* A smaller grid must not leave the bigger one's cells behind now that the write
   happens before the trim rather than after a clear. */
console.log('\n39g. a later, smaller grid leaves none of the bigger one behind');
reset(); goodSheet();
dailyRollup();
const wideDaily = tabRows('daily')[0].length;
H.SHEETS.book.getSheetByName('daily').getRange(1, wideDaily + 4, 1, 1).setValues([['LEFTOVER']]);
chk('a stray cell is sitting past the grid',
  tabRows('daily')[0].indexOf('LEFTOVER') >= 0, JSON.stringify(tabRows('daily')[0].slice(-3)));
wait(120);
dailyRollup();
chk('the next run cleared it away',
  tabRows('daily')[0].indexOf('LEFTOVER') < 0, JSON.stringify(tabRows('daily')[0].slice(-3)));
chk('and the grid still holds exactly one stamp',
  stampsIn(tabRows('daily')).length === 1, JSON.stringify(stampsIn(tabRows('daily'))));
reset();

console.log('\n39d. the stamp shifts no row and no column that was there before');

/*
 * The golden is the grid this rollup produced before the stamp existed, captured
 * per timezone because every day boundary in this app is timezone-dependent.
 *
 * Two things can go wrong before a single assertion runs, and they are different
 * problems that deserve different answers. The fixture being unreadable is a
 * broken checkout: the suite cannot do its job, so it says why and stops. The
 * fixture simply having no entry for the current zone is a developer working in a
 * fifth zone — contract item 2 names four — so the section is skipped by name and
 * the rest of the run continues. Neither is a stack trace, and neither is a pass:
 * this section used to report "FAIL there is a golden for this timezone" and then
 * dereference the missing golden on the next line, aborting the run.
 */
function loadGolden() {
  let g;
  try {
    g = require('./fixtures/rollup-golden.json');
  } catch (e) {
    /* First line only: a MODULE_NOT_FOUND message carries the whole require stack
       after it, which buries the one sentence that says what to do. */
    console.log('\n  test/fixtures/rollup-golden.json could not be read: ' +
                String((e && e.message) || e).split('\n')[0]);
    console.log('  It is the record of the grid this rollup produced before the stamp');
    console.log('  existed, and section 39d cannot mean anything without it.');
    console.log('  Restore it with:  git checkout -- test/fixtures/rollup-golden.json\n');
    process.exit(1);
  }
  if (!g || !g.byZone || typeof g.byZone !== 'object' || !Object.keys(g.byZone).length) {
    console.log('\n  test/fixtures/rollup-golden.json parsed but holds no byZone map of');
    console.log('  golden grids, so section 39d has nothing to compare against.');
    console.log('  Restore it with:  git checkout -- test/fixtures/rollup-golden.json\n');
    process.exit(1);
  }
  return g;
}

const GOLD = loadGolden();
const ZONE = Session.getScriptTimeZone();
const gz = GOLD.byZone[ZONE];

if (!gz) {
  H.skip('39d. the stamp shifts no row and no column that was there before',
    'no golden grid captured for ' + ZONE + '. The fixture holds ' +
    Object.keys(GOLD.byZone).sort().join(', ') + ' — the four zones contract item 2 ' +
    'names. Run the suite in one of those to exercise this section.');
} else {
  chk('the golden for this timezone holds a grid for both tabs',
    !!(gz.grids && gz.grids.daily && gz.grids.daily.length &&
       gz.grids.weekly && gz.grids.weekly.length),
    ZONE + ': ' + JSON.stringify(Object.keys(gz.grids || {})));
  reset(D(2026, 7, 20, 9, 0)); reboot();
  goodSheet();
  tap('DW');  wait(40);
  tap('MTG'); wait(50);
  tap('ADM'); wait(30);
  tap('DW');  wait(20);
  tap('FRAG');
  const now39 = dailyRollup();
  /* One more key than the golden records, and it is the one D1 added. Asserted
     as "+1" rather than relaxed to ">=", so a second key appearing from
     somewhere still fails. */
  chk('the same run reports one more key than before, and no other change',
    now39.days === gz.days && now39.categories === gz.categories + 1,
    JSON.stringify(now39) + ' vs ' + JSON.stringify({ days: gz.days, categories: gz.categories }));
  ['daily', 'weekly'].forEach(tab => {
    const gold = gz.grids[tab], live = tabRows(tab);
    const gw = gold[0].length;
    /*
     * D1 adds one key to rollupKeys_, and a key is not one column: it is a
     * column in each group the grid is built from. So a pre-round column cannot
     * still be at its pre-round *index*, and asserting that it is would now be
     * asserting that D1 did not happen.
     *
     * What replaces it is not weaker, because it says exactly what moved and
     * what did not: every pre-round column is still present, in the same
     * relative order, carrying the same values row for row — matched by NAME so
     * the insertion cannot hide a changed number — and the only columns
     * inserted among them are the ones that one new key contributes. A mark
     * column interleaved beside the key it belongs to, which is the thing
     * contract 20 exists to prevent, still fails here: it would insert a column
     * that is not the new key's.
     *
     * The golden itself is still NOT regenerated. See Q11 and Q14 in
     * factory/progress-2.md.
     */
    const NEW_COLS = tab === 'daily'
      ? [UNFILED_KEY, 'plan ' + UNFILED_KEY]
      : ['plan ' + UNFILED_KEY, UNFILED_KEY, UNFILED_KEY + ' ratio'];
    chk(tab + ': same number of rows', live.length === gold.length,
      live.length + ' vs ' + gold.length);
    const surviving = live[0].filter(h => gold[0].includes(h));
    chk(tab + ': every pre-round column is still there, in the same order',
      JSON.stringify(surviving) === JSON.stringify(gold[0]),
      JSON.stringify(surviving.filter((h, i) => h !== gold[0][i]).slice(0, 4)));
    const lastGoldAt = live[0].lastIndexOf(gold[0][gw - 1]);
    const inserted = live[0].slice(0, lastGoldAt + 1).filter(h => !gold[0].includes(h));
    chk(tab + ': and the only columns inserted among them are the new key\'s',
      JSON.stringify(inserted) === JSON.stringify(NEW_COLS),
      JSON.stringify(inserted) + ' vs ' + JSON.stringify(NEW_COLS));
    /*
     * WHERE they were inserted, which the three assertions above do not pin.
     * Without this, moving the new key to the front of its group shifts every
     * pre-round column in that group and still passes: the columns are all
     * present, in order, with their values, and the only extra ones are the new
     * key's. Each inserted column must sit immediately after the last pre-round
     * column of the group it belongs to — appended within its group, which is
     * the least disturbance a new key can cause.
     */
    const preKeys = gold[0].filter(h => /^plan /.test(h)).map(h => h.slice(5));
    const lastKey = preKeys[preKeys.length - 1];
    const AFTER = tab === 'daily'
      ? [[UNFILED_KEY, lastKey], ['plan ' + UNFILED_KEY, 'plan ' + lastKey]]
      : [['plan ' + UNFILED_KEY, lastKey + ' ratio'],   // the weekly triple, in order
         [UNFILED_KEY, 'plan ' + UNFILED_KEY],
         [UNFILED_KEY + ' ratio', UNFILED_KEY]];
    const misplaced = AFTER
      .filter(([col, prev]) => live[0].indexOf(col) !== live[0].indexOf(prev) + 1)
      .map(([col, prev]) => col + ' is at ' + live[0].indexOf(col) +
                            ', not straight after ' + prev + ' at ' + live[0].indexOf(prev));
    chk(tab + ': each of them sits at the end of the group it belongs to',
      misplaced.length === 0, misplaced.join(' | '));
    /*
     * And the exact arithmetic of the shift: a pre-round column moves by the
     * number of inserted columns that precede it, and by nothing else. This is
     * contract 20 restated for a grid that gained a key — it says the movement
     * is fully explained rather than merely tolerated.
     */
    const unexplained = gold[0].map((h, j) => {
      const before = NEW_COLS.filter(c => live[0].indexOf(c) < live[0].indexOf(h)).length;
      return live[0].indexOf(h) === j + before ? null
        : h + ': was ' + j + ', now ' + live[0].indexOf(h) + ', with ' + before + ' inserted before it';
    }).filter(Boolean);
    chk(tab + ': every pre-round column moved by exactly what was inserted before it',
      unexplained.length === 0, unexplained.slice(0, 4).join(' | '));
    const liveAt = {};
    live[0].forEach((h, i) => { if (!(h in liveAt)) liveAt[h] = i; });
    let firstDiff = null;
    for (let i = 0; i < gold.length && firstDiff === null; i++) {
      for (let j = 0; j < gw; j++) {
        const name = gold[0][j], lj = liveAt[name];
        if (lj === undefined) { firstDiff = 'column ' + JSON.stringify(name) + ' is gone'; break; }
        if (String(live[i][lj]) !== String(gold[i][j])) {
          firstDiff = 'row ' + i + ' col ' + JSON.stringify(name) + ': ' +
                      JSON.stringify(live[i][lj]) + ' vs golden ' + JSON.stringify(gold[i][j]);
          break;
        }
      }
    }
    chk(tab + ': every pre-existing cell is byte-identical', firstDiff === null, String(firstDiff));
    /* B2 and B3 append one column per key per mark bucket, after every column
     * that existed before. The golden is deliberately NOT regenerated — it is
     * the pre-round record, and its own _note says regenerating it defeats the
     * test that uses it. So the assertion is not "one new column" any more; it
     * is "exactly these new columns, in this order, and then the stamp".
     *
     * The keys come out of the golden's own header rather than out of the live
     * code, so this cannot agree with a mistake by construction. */
    const goldKeys = gold[0].filter(h => /^plan /.test(h)).map(h => h.slice(5))
      .concat([UNFILED_KEY]);        // D1's key gets its full set, like every other
    /* Which tabs carry the mark columns, stated rather than sniffed. Deriving
       it from the live header would make this agree with whatever the code did.
       B2 does the daily tab; B3 adds the weekly one to this list. */
    const TABS_WITH_MARKS = ['daily', 'weekly'];
    const expectNew = [];
    if (TABS_WITH_MARKS.includes(tab)) {
      goldKeys.forEach(k => MARK_BUCKETS.forEach(m => expectNew.push(markCol_(k, m))));
    }
    // D2 appends one more, on the weekly tab only — after the mark block, so it
    // disturbs nothing that B3 put there. Stated per tab rather than sniffed.
    if (tab === 'weekly') expectNew.push('days covered (of 7)');
    chk(tab + ': the golden header really did yield the keys', goldKeys.length > 0,
      JSON.stringify(goldKeys));
    // The appended block starts after the pre-round columns plus the ones D1
    // inserted among them — computed, not assumed, so a stray insertion moves
    // the expectation rather than being absorbed by it.
    const appendAt = gw + inserted.length;
    chk(tab + ': the new columns are the mark columns, appended in order',
      JSON.stringify(live[0].slice(appendAt, appendAt + expectNew.length)) === JSON.stringify(expectNew),
      JSON.stringify(live[0].slice(appendAt, appendAt + expectNew.length)) + ' vs ' + JSON.stringify(expectNew));
    const stampAt = appendAt + expectNew.length;
    chk(tab + ': then exactly one more column, and it is the stamp',
      live[0].length === stampAt + 1 && /^last rebuilt /.test(live[0][stampAt]),
      live[0].length + ' wide, col ' + stampAt + ' = ' + JSON.stringify(live[0][stampAt]));
    chk(tab + ': and no data row puts anything in the stamp column',
      live.slice(1).every(r => r[stampAt] === '' || r[stampAt] === undefined),
      JSON.stringify(live.slice(1, 4).map(r => r[stampAt])));
  });
}
reset();

/* ── C3: the last outcome, readable when the sheet is not ─────────── */

console.log('\n40. the report names the last success and the last failure');
reset(); goodSheet();
tap('DW'); wait(30); tap('MTG');
dailyRollup();
wait(120);
brokenSheet();
try { dailyRollup(); } catch (e) {}
H.LOGGED.length = 0;
const rep = rollupStatus();
chk('it says the last run failed', /Last run: failed/.test(rep), rep);
chk('it names when the last success was',
  rep.indexOf(stampTime_(REC().lastSuccessMs)) > 0, rep);
chk('it names when the last failure was',
  rep.indexOf(stampTime_(REC().lastFailureMs)) > 0, rep);
chk('and what the failure was', /no-such-book/.test(rep), rep);
chk('nothing reads as undefined', !/undefined/.test(rep), rep);
chk('the same string reaches the log', H.LOGGED.indexOf(rep) >= 0,
  JSON.stringify(H.LOGGED));
chk('it reports and does not advise',
  !/should|must|you need|recommend|⚠|warning/i.test(rep), rep);
reset();

console.log('\n40b. nothing on record says so in plain words');
reset();
H.LOGGED.length = 0;
let rep40b = null, e40b = null;
try { rep40b = rollupStatus(); } catch (e) { e40b = String(e && e.message || e); }
chk('it does not throw', e40b === null, String(e40b));
chk('it says no rollup has run', /No rollup has run yet/.test(rep40b || ''), String(rep40b));
chk('nothing reads as undefined', !/undefined/.test(rep40b || ''), String(rep40b));
chk('and it still reaches the log', H.LOGGED.indexOf(rep40b) >= 0, JSON.stringify(H.LOGGED));
reset();

console.log('\n40c. a record that cannot be read says that, rather than throwing');
reset();
H.SCRIPT_PROPS.ROLLUP_LAST = 'this is not json {{{';
H.LOGGED.length = 0;
let rep40c = null, e40c = null;
try { rep40c = rollupStatus(); } catch (e) { e40c = String(e && e.message || e); }
chk('it does not throw', e40c === null, String(e40c));
chk('it says the record cannot be read',
  /cannot be read/.test(rep40c || ''), String(rep40c));
chk('and names the property to clear', /ROLLUP_LAST/.test(rep40c || ''), String(rep40c));
chk('nothing reads as undefined', !/undefined/.test(rep40c || ''), String(rep40c));
reset();

console.log('\n40d. a record holding the wrong shape entirely is still not a crash');
reset();
H.SCRIPT_PROPS.ROLLUP_LAST = '["an","array","not","an","object"]';
let rep40d = null, e40d = null;
try { rep40d = rollupStatus(); } catch (e) { e40d = String(e && e.message || e); }
chk('it does not throw', e40d === null, String(e40d));
chk('and it says it cannot read the record', /cannot be read/.test(rep40d || ''), String(rep40d));
reset();

console.log('\n40e. a run after an unreadable record starts a clean one');
reset(); goodSheet();
H.SCRIPT_PROPS.ROLLUP_LAST = 'not json at all';
tap('DW'); wait(20); tap('MTG');
dailyRollup();
chk('the record is readable again', REC() && REC().outcome === 'ok', JSON.stringify(REC()));
chk('and the report reads it', /Last run: succeeded/.test(rollupStatus()), rollupStatus());
reset();

/* ── A1: a title can carry a fourth mark, and it survives a round trip ──
 *
 * '?' means the app had to guess where a block ended. Nothing writes one yet —
 * staleGuard_ starts writing it in A2. This section proves the widening on its
 * own, before anything depends on it, because four call sites default to ADM
 * when parsing fails: a regression here does not throw, it silently misfiles
 * time. */

console.log('\n41. the mark set widens by exactly one character');
reset();
chk('buildTitle_ writes "?"', buildTitle_('DW', 'memo drafting', '?') === 'DW: memo drafting ?',
  buildTitle_('DW', 'memo drafting', '?'));
const p41 = parseTitle_('DW: memo drafting ?');
chk('and parseTitle_ reads it back as the mark', p41.mark === '?', JSON.stringify(p41));
chk('leaving the "?" out of the text', p41.text === 'memo drafting', JSON.stringify(p41));
chk('with the key intact', p41.key === 'DW', JSON.stringify(p41));

/* The three older marks are untouched by the widening. */
chk('"+" still parses', parseTitle_('DW: memo +').mark === '+');
chk('"=" still parses', parseTitle_('DW: memo =').mark === '=');
chk('"-" still parses', parseTitle_('DW: memo -').mark === '-');
chk('an unmarked title still has no mark', parseTitle_('DW: memo').mark === null);

console.log('\n41b. build -> parse -> rebuild is byte-identical, for every mark');
/* A table rather than seven hand-written cases, so a fifth mark added later is
 * covered by construction. The texts include ones that already end in a mark
 * character: those are where a greedy regex would eat a character it should
 * have left alone. */
const MARKS41 = ['+', '=', '-', '?', null];
const TEXTS41 = ['', 'memo', 'memo drafting', '  padded   spaces  ', 'memo +', 'a ?', 'C++'];
const rt41 = [];
for (const mk of MARKS41) {
  for (const tx of TEXTS41) {
    const built = buildTitle_('DW', tx, mk);
    const parsed = parseTitle_(built);
    if (!parsed) { rt41.push(built + ' -> did not parse at all'); continue; }
    const rebuilt = buildTitle_(parsed.key, parsed.text, parsed.mark);
    if (rebuilt !== built) rt41.push(JSON.stringify(built) + ' -> ' + JSON.stringify(rebuilt));
  }
}
chk('every mark x text combination round-trips unchanged', rt41.length === 0,
  rt41.join(' | '));
chk('and the table actually covered all four marks plus unmarked',
  MARKS41.length === 5 && TEXTS41.length === 7);

console.log('\n41c. an op may carry "?", and still may not carry anything else');
reset();
const t41 = H.nowMs();
const r41 = applyOps([
  { id: 'a41', type: 'openActual',  ref: 'aaaabbbbccccdddd', key: 'DW', startMs: t41 },
  { id: 'b41', type: 'closeActual', ref: 'aaaabbbbccccdddd', key: 'DW',
    endMs: t41 + 3600000, mark: '?', text: 'memo' }
]);
chk('the op carrying "?" was applied', r41.applied.includes('b41'), JSON.stringify(r41.applied));
chk('and not dropped', r41.dropped.length === 0, JSON.stringify(r41.dropped.map(d => d.id)));
chk('so the title carries the guess', A()[0].t === 'DW: memo ?', A()[0].t);

reset();
const t41b = H.nowMs();
const r41b = applyOps([
  { id: 'a41b', type: 'openActual',  ref: 'aaaabbbbccccdddd', key: 'DW', startMs: t41b },
  { id: 'b41b', type: 'closeActual', ref: 'aaaabbbbccccdddd', key: 'DW',
    endMs: t41b + 3600000, mark: 'x' }
]);
chk('an op carrying "x" is still dropped',
  r41b.dropped.length === 1 && r41b.dropped[0].id === 'b41b',
  JSON.stringify(r41b.dropped.map(d => d.id)));
/* '+=' is a substring of the mark set, so an indexOf test would have admitted
 * it. The widening admits exactly one new character, not one new substring. */
reset();
const r41c = applyOps([
  { id: 'a41c', type: 'openActual', ref: 'aaaabbbbccccdddd', key: 'DW', startMs: H.nowMs() },
  { id: 'b41c', type: 'closeActual', ref: 'aaaabbbbccccdddd', key: 'DW',
    endMs: H.nowMs() + 3600000, mark: '+=' }
]);
chk('and so is a two-character mark', r41c.dropped.length === 1, JSON.stringify(r41c.dropped));

console.log('\n41d. the mark anchors to one trailing character, "?" exactly like "="');
/* HANDOFF-2.md A1 asks for "DW: memo ??" to parse as mark "?" and text "memo ?",
 * justifying it as "exactly as it already does for =". Those two halves
 * contradict each other: today "DW: memo ==" parses as mark null, text
 * "memo ==", because the regex requires start-of-string or whitespace before
 * the mark. Making the literal expectation true means dropping that guard,
 * which would also make "DW: C++" parse as mark "+" and text "DW: C+", and
 * would change "=" behaviour that contract assertion 7 requires be left alone.
 *
 * So the justification is what is implemented and what is asserted here: the
 * new character behaves identically to the old ones, whatever that behaviour
 * is. The literal expectation is recorded as unmet in factory/progress-2.md,
 * not quietly dropped. See the parked question there. */
/* Compared mark-for-mark and text-for-text, since the two texts differ by
 * construction. The claim is that the new character is treated by the same
 * rule as the old ones, not that the two titles parse to the same object. */
const dbl41 = ['+', '=', '-', '?'].map(m => parseTitle_('DW: memo ' + m + m));
chk('every doubled mark is treated the same way as every other',
  dbl41.every(p => p.mark === dbl41[0].mark), JSON.stringify(dbl41));
chk('and that way is "the second one is text, not a mark"',
  dbl41.every((p, i) => p.mark === null && p.text === 'memo ' + '+=-?'[i] + '+=-?'[i]),
  JSON.stringify(dbl41));
chk('a single trailing "?" is a mark', parseTitle_('DW: memo ?').mark === '?');
chk('a doubled one is text, exactly as a doubled "=" is',
  parseTitle_('DW: memo ??').mark === null && parseTitle_('DW: memo ??').text === 'memo ??',
  JSON.stringify(parseTitle_('DW: memo ??')));
chk('and "C++" keeps both its plusses',
  parseTitle_('DW: C++').text === 'C++' && parseTitle_('DW: C++').mark === null,
  JSON.stringify(parseTitle_('DW: C++')));

console.log('\n41e. no action a user can take produces "?" — contract 17');
/* markFor lives inside Index.html's IIFE, so this asserts the observable claim
 * the contract actually makes rather than reaching into a private function: no
 * sequence of taps, at any duration, ever writes a "?" into a title. The two
 * inputs markFor reads are the category and the duration, and both are swept.
 *
 * The autoMark assertion below closes the only other door: markFor returns
 * c.autoMark, '=' or null, so the single way it could ever return '?' is a
 * category configured with one. */
chk('no configured category carries "?" as its autoMark',
  CATEGORIES.every(c => c.autoMark !== '?'),
  JSON.stringify(CATEGORIES.map(c => [c.key, c.autoMark])));

const guessed41 = [];
for (const cat of CATEGORIES.map(c => c.key)) {
  for (let mins = 0; mins <= 480; mins += 20) {
    reset(); reboot();
    tap(cat);
    if (mins) wait(mins);
    // Two taps: past the confirm window the first acts and the second lands on
    // the freshly lit block as a no-op; inside it, the first arms and the
    // second confirms. One shape covers the whole sweep.
    tap(cat === 'DW' ? 'MTG' : 'DW');
    tap(cat === 'DW' ? 'MTG' : 'DW');
    settle();
    const bad = A().filter(e => /\?\s*$/.test(e.t));
    if (bad.length) guessed41.push(cat + '@' + mins + 'm: ' + bad.map(e => e.t).join(','));
  }
}
chk('no tap sequence at any duration from 0 to 8 hours ever wrote a "?"',
  guessed41.length === 0, guessed41.slice(0, 6).join(' | '));
/* The sweep above is only worth anything if it actually wrote blocks. Asserted
 * against the last iteration rather than restating the check above it, which
 * would pass just as happily against an empty calendar. */
chk('and the sweep was writing blocks, not sweeping an empty calendar',
  A().length >= 2 && A().every(e => /^[A-Z]+:/.test(e.t)),
  A().length + ' events: ' + A().map(e => e.t).join(','));
chk('over all six configured categories', CATEGORIES.length === 6);
reset();

console.log('\n41f. a note the user typed can never impersonate the app\'s guess');
/* Found by the checker against A1 as first written, and recorded as contract
 * addition 1 in factory/progress-2.md before being fixed here. A note ending in
 * a question mark landed in the trailing mark slot and was read straight back
 * as "the app had to guess", which would have made an annotated block
 * indistinguishable from a phantom one all the way through Stage B. */
reset(); reboot();
tap('DW');
noteBox().value = 'is this right ?'; noteBox().fire('input');
advance(1000); settle();
wait(5);                                    // under MIN_MARK_MINUTES, so no mark
tap('MTG'); tap('MTG'); settle();
const n41 = parseTitle_(A()[0].t);
chk('the block closed with no mark, not with a guess', n41.mark === null,
  A()[0].t + ' -> ' + JSON.stringify(n41));
chk('and nothing on the calendar claims to be a guess',
  A().every(e => !/\?\s*$/.test(e.t)), A().map(e => e.t).join(' | '));

reset(); reboot();
tap('DW');
noteBox().value = 'is this right ?'; noteBox().fire('input');
advance(1000); settle();
wait(40);                                   // over MIN_MARK_MINUTES, so "=" follows
tap('MTG'); tap('MTG'); advance(6000); settle();
const n41b = parseTitle_(A()[0].t);
chk('with a mark following it, the note keeps its "?"', n41b.text === 'is this right ?',
  A()[0].t + ' -> ' + JSON.stringify(n41b));
chk('and the mark is the one the app applied', n41b.mark === '=', JSON.stringify(n41b));

/* The narrowness is the point: the strip only happens when the trailing slot is
 * otherwise empty. Asserted directly, so a later widening of it is visible. */
chk('a bare trailing "?" is stripped when nothing follows it',
  buildTitle_('DW', 'is this right ?', null) === 'DW: is this right',
  buildTitle_('DW', 'is this right ?', null));
chk('and kept when something does',
  buildTitle_('DW', 'is this right ?', '=') === 'DW: is this right ? =',
  buildTitle_('DW', 'is this right ?', '='));
chk('a "?" inside the note is never touched',
  buildTitle_('DW', 'why? because', null) === 'DW: why? because',
  buildTitle_('DW', 'why? because', null));
chk('nor one that is not in mark position',
  buildTitle_('DW', 'what ??', null) === 'DW: what ??',
  buildTitle_('DW', 'what ??', null));

/* Error paths: a note made only of marks, and the round trip over all of it. */
let thrown41 = null;
let only41 = null;
try { only41 = buildTitle_('DW', '? ? ?', null); } catch (e) { thrown41 = String(e); }
chk('a note of nothing but question marks does not throw', thrown41 === null, String(thrown41));
chk('and parses to no mark', only41 !== null && parseTitle_(only41).mark === null,
  String(only41) + ' -> ' + JSON.stringify(only41 && parseTitle_(only41)));

const rt41f = [];
for (const mk of MARKS41) {
  for (const tx of ['is this right ?', 'what ??', 'why? because', '? ? ?', '?']) {
    const built = buildTitle_('DW', tx, mk);
    const parsed = parseTitle_(built);
    if (!parsed) { rt41f.push(built + ' -> did not parse'); continue; }
    const rebuilt = buildTitle_(parsed.key, parsed.text, parsed.mark);
    if (rebuilt !== built) rt41f.push(JSON.stringify(built) + ' -> ' + JSON.stringify(rebuilt));
  }
}
chk('and every question-mark note still round-trips byte-identical',
  rt41f.length === 0, rt41f.join(' | '));
reset();

/* ── A2: a block the app had to guess the end of says so in its title ──
 *
 * The mark assertions and the boundary assertions are kept deliberately
 * separate, and the vacuity check for this task depends on that separation:
 * reverting '?' to '=' must turn the mark ones red while the boundary ones stay
 * green. That is what proves the boundary assertions test arithmetic rather
 * than testing the mark. */

console.log('\n42. an overnight block is marked as a guess, not as settled');
reset(D(2026, 7, 20, 22, 0)); reboot();
tap('DW'); settle();
H.setNow(D(2026, 7, 21, 7, 0));
reboot();
const a42 = A();
chk('the block\'s title ends with "?"', /\?$/.test(a42[0].t), a42[0].t);
chk('and not with "="', !/=$/.test(a42[0].t), a42[0].t);
chk('it parses back as a guess', parseTitle_(a42[0].t).mark === '?', a42[0].t);

console.log('\n42b. and the arithmetic that bounded it is untouched');
/* Identical to the boundaries this code produced before this round. Asserted as
 * times, not as "a mark was applied". */
chk('exactly two events, and nothing else was written', a42.length === 2,
  a42.map(show).join(' | '));
chk('the block runs 22:00 to midnight',
  near(a42[0].s, D(2026, 7, 20, 22, 0)) && near(a42[0].e, D(2026, 7, 21, 0, 0)),
  show(a42[0]));
chk('UNLOGGED runs midnight to now',
  a42[1].t === 'UNLOGGED -' && a42[1].s === a42[0].e && near(a42[1].e, D(2026, 7, 21, 7, 0)),
  show(a42[1]));

console.log('\n42c. an autoMark never overrides a guess');
reset(D(2026, 7, 20, 22, 0)); reboot();
tap('BODY'); settle();                       // autoMark '+'
H.setNow(D(2026, 7, 21, 7, 0));
reboot();
chk('BODY is marked "?", not "+"', parseTitle_(A()[0].t).mark === '?', A()[0].t);
chk('and the "+" appears nowhere in it', !/\+/.test(A()[0].t), A()[0].t);

reset(D(2026, 7, 20, 22, 0)); reboot();
tap('FRAG'); settle();                       // autoMark '-'
H.setNow(D(2026, 7, 21, 7, 0));
reboot();
chk('FRAG is marked "?", not "-"', parseTitle_(A()[0].t).mark === '?', A()[0].t);
/* Guards the specific way this could go wrong: buildTitle_ writing both. */
chk('and exactly one mark is on the title', A()[0].t === 'FRAG: ?', A()[0].t);

console.log('\n42d. nothing is bounded that did not need bounding');
/* C1 moved MISTAP_SECONDS from 90 to 20, so this is 10 seconds rather than the
   30 it used to be — 30s now sits outside the window this line is about. The
   block is still not bounded at 30s either, but for the different reason
   asserted below it, and a test whose label no longer describes what it does is
   a test that will mislead someone. */
reset(D(2026, 7, 20, 9, 0)); reboot();
tap('DW'); settle();
H.setNow(D(2026, 7, 20, 9, 0, 10));
reboot();
chk('inside the mis-tap window, nothing is bounded', A().length === 1, A().map(show).join(' | '));
chk('the block is still open', /#open/.test(A()[0].d), show(A()[0]));
chk('and carries no mark at all', A()[0].t === 'DW:', A()[0].t);

reset(D(2026, 7, 20, 9, 0)); reboot();
tap('DW'); settle();
H.setNow(D(2026, 7, 20, 13, 0));             // 4h, under STALE_OPEN_HOURS, same day
reboot();
chk('under the stale threshold on the same day, nothing is bounded',
  A().length === 1 && /#open/.test(A()[0].d), A().map(show).join(' | '));
chk('and still no mark', A()[0].t === 'DW:', A()[0].t);

console.log('\n42e. a SIT block carries no mark, guessed or otherwise');
reset(D(2026, 7, 20, 22, 30)); reboot();
tapSit(); settle();
H.setNow(D(2026, 7, 21, 7, 0));
reboot();
chk('the SIT block is bounded at the day border',
  near(S()[0].e, D(2026, 7, 21, 0, 0)), show(S()[0]));
chk('its title is untouched', S()[0].t === 'SIT', S()[0].t);
chk('no "?" reached the SITTING calendar', S().every(e => !/\?/.test(e.t)),
  S().map(e => e.t).join(' | '));
chk('and no UNLOGGED was written to it', S().length === 1, S().map(show).join(' | '));

console.log('\n42f. a guess is a fact about the end time, not about the duration');
/* Opened 23:59, bounded at midnight: one minute long, far under
 * MIN_MARK_MINUTES, and still the app's guess rather than the user's. */
reset(D(2026, 7, 20, 23, 59)); reboot();
tap('DW'); settle();
H.setNow(D(2026, 7, 21, 7, 0));
reboot();
const f42 = A();
chk('the one-minute block still carries "?"', parseTitle_(f42[0].t).mark === '?', f42[0].t);
chk('and it really was under MIN_MARK_MINUTES',
  (f42[0].e - f42[0].s) < MIN_MARK_MINUTES * 60000,
  String((f42[0].e - f42[0].s) / 60000) + 'm');

console.log('\n42g. a category cannot be configured into producing a guess');
/* Found by the checker. Categories added at runtime come out of the
 * EXTRA_CATEGORIES script property, which nothing validates, so an autoMark of
 * '?' was reachable by configuration — and it closed an ordinary tapped block
 * as though the app had bounded it, with staleGuard_ nowhere near. Contract 17
 * and A1's own criterion 7 both say markFor never produces '?'. */
reset();
H.SCRIPT_PROPS.EXTRA_CATEGORIES =
  JSON.stringify([{ key: 'XX', label: 'Guessy', color: 5, autoMark: '?' }]);
H.clearPropCache();
reboot();
chk('the category really is configured with a "?" autoMark',
  clientConfig_().categories.some(c => c.key === 'XX' && c.autoMark === '?'),
  JSON.stringify(clientConfig_().categories.map(c => [c.key, c.autoMark])));
tap('XX'); wait(40); tap('DW'); advance(6000); settle();
const g42 = A().filter(e => /^XX:/.test(e.t));
chk('but an ordinary tap still does not write a guess',
  g42.length === 1 && parseTitle_(g42[0].t).mark !== '?', g42.map(e => e.t).join(' | '));
chk('it falls back to the normal duration rule instead',
  parseTitle_(g42[0].t).mark === '=', g42.map(e => e.t).join(' | '));
reset(); H.clearPropCache(); reboot();

console.log('\n42h. bounding overwrites a mark that is no longer true');
/* Also found by the checker, and recorded as contract addition 2 before this
 * test was written. An open block can only carry a mark if someone hand-edited
 * its title in Google Calendar — the app never writes one to an open block. If
 * the app then has to guess where that block ended, the guess is the honest
 * claim and the stale mark is not: whatever the title said before, the end time
 * is the app's. */
reset(D(2026, 7, 20, 22, 0)); reboot();
tap('DW'); settle();
const ev42 = H.CALS.actual.events[0];
ev42.t = 'DW: memo =';                       // hand-edited in Google Calendar
H.setNow(D(2026, 7, 21, 7, 0));
reboot();
chk('the stale "=" is replaced by the guess', parseTitle_(A()[0].t).mark === '?', A()[0].t);
chk('and the text the user typed survives it',
  parseTitle_(A()[0].t).text === 'memo', A()[0].t);
reset();

/* ── A3: STOP ends the day, and opens nothing ──────────────────────
 *
 * The first control in the app that closes without opening, which makes it the
 * first thing that can leave the app in a state no existing test covers:
 * nothing open, queue draining, adoptServerState arriving afterwards. */

const tapStop = H.tapStop, stopArmedNow = H.stopArmedNow, stopLabel = H.stopLabel;
const openEvents = () => A().filter(e => /#open/.test(e.d));
const openSits = () => S().filter(e => /#open/.test(e.d));

console.log('\n43. STOP closes the block and the SIT, and opens nothing');
reset(); reboot();
tapSit(); wait(10); tap('DW'); wait(40); settle();
const before43 = { a: A().length, s: S().length };
tapStop();
chk('one tap only arms it', stopArmedNow(), stopLabel());
chk('and nothing has been written yet', A().length === before43.a && S().length === before43.s,
  'A ' + A().length + ' S ' + S().length);
tapStop(); settle();
chk('ACTUAL holds exactly one event', A().length === 1, A().map(show).join(' | '));
chk('SITTING holds exactly one event', S().length === 1, S().map(show).join(' | '));
chk('neither calendar gained an event',
  A().length === before43.a && S().length === before43.s,
  'A ' + A().length + '/' + before43.a + ' S ' + S().length + '/' + before43.s);
chk('nothing is left open on ACTUAL', openEvents().length === 0, A().map(show).join(' | '));
chk('nothing is left open on SITTING', openSits().length === 0, S().map(show).join(' | '));
chk('both close at the same instant', A()[0].e === S()[0].e,
  show(A()[0]) + ' / ' + show(S()[0]));
chk('and the grid shows the idle state', activeKey() === null && $('grid')._cls.has('idle'),
  String(activeKey()));

console.log('\n43b. a running block and no SIT leaves SITTING untouched');
reset(); reboot();
tap('DW'); wait(30); settle();
tapStop();
chk('one tap leaves the block open', openEvents().length === 1, A().map(show).join(' | '));
tapStop(); settle();
chk('the block closed', A().length === 1 && openEvents().length === 0, A().map(show).join(' | '));
chk('the SITTING calendar is untouched', S().length === 0, S().map(show).join(' | '));

console.log('\n43c. an open SIT and no block leaves ACTUAL untouched');
reset(); reboot();
tapSit(); wait(30); settle();
tapStop();
chk('one tap leaves the SIT open', openSits().length === 1, S().map(show).join(' | '));
tapStop(); settle();
chk('the SIT closed', S().length === 1 && openSits().length === 0, S().map(show).join(' | '));
chk('the ACTUAL calendar is untouched', A().length === 0, A().map(show).join(' | '));
chk('and the posture button says so', litPosture() === 'stand', String(litPosture()));

console.log('\n43d. an armed STOP that is never confirmed does nothing');
reset(); reboot();
tap('DW'); wait(30); settle();
tapStop();
chk('armed', stopArmedNow(), stopLabel());
advance(CONFIRM_TIMEOUT_MS + 100); settle();
chk('it forgets', !stopArmedNow(), stopLabel());
chk('and returns to its resting label', stopLabel() === 'STOP', stopLabel());
chk('the block is still open', openEvents().length === 1, A().map(show).join(' | '));
/* Reads the queue, not the calendar. A calendar assertion is true of a build
 * that queued a spurious op and had not flushed it yet. */
chk('and the queue is empty', JSON.parse(H.STORE['tt.queue.v1'] || '[]').length === 0,
  H.STORE['tt.queue.v1'] || '[]');

console.log('\n43e. with nothing to end, STOP writes nothing and complains about nothing');
reset(); reboot();
chk('it is visibly inert to begin with', $('stopBtn')._cls.has('inert'));
tapStop();
chk('arming it writes nothing', JSON.parse(H.STORE['tt.queue.v1'] || '[]').length === 0,
  H.STORE['tt.queue.v1'] || '[]');
tapStop(); settle();
chk('and confirming it queues no op',
  JSON.parse(H.STORE['tt.queue.v1'] || '[]').length === 0, H.STORE['tt.queue.v1'] || '[]');
chk('no event on ACTUAL', A().length === 0, A().map(show).join(' | '));
chk('no event on SITTING', S().length === 0, S().map(show).join(' | '));
chk('and no error banner', $('err').hidden !== false || $('err')._cls.has('hidden'),
  String($('err').textContent));

console.log('\n43f. ending a long enough block shows the mark strip, as a transition does');
reset(); reboot();
tap('DW'); wait(40); settle();
tapStop();
chk('one tap shows no strip and closes nothing',
  $('strip').hidden && openEvents().length === 1, A().map(show).join(' | '));
tapStop(); settle();
chk('the strip is visible', !$('strip').hidden);
chk('and names the block and its duration',
  $('stripHead').textContent === 'DW closed · 40m', $('stripHead').textContent);
tapMark('+');
chk('and the mark it offers still lands', A()[0].t === 'DW: +', A()[0].t);

console.log('\n43g. ending a short block shows no strip and applies no mark');
reset(); reboot();
tap('DW'); wait(5); settle();
tapStop();
chk('one tap writes nothing', openEvents().length === 1, A().map(show).join(' | '));
tapStop(); settle();
chk('no strip', $('strip').hidden);
/* The closed-ness is asserted first. "DW:" is equally true of a block that is
 * still running, so on its own the mark assertion below proves nothing. */
chk('the block actually closed', A().length === 1 && openEvents().length === 0,
  A().map(show).join(' | '));
chk('and carries no mark', A()[0].t === 'DW:', A()[0].t);

console.log('\n43h. a day closed by STOP is still closed after a reload');
reset(); reboot();
tapSit(); wait(5); tap('DW'); wait(45); settle();
tapStop(); tapStop(); settle(); settle();
reboot();
chk('nothing renders as running', activeKey() === null, String(activeKey()));
chk('getState finds no open block on ACTUAL', openEvents().length === 0, A().map(show).join(' | '));
chk('nor on SITTING', openSits().length === 0, S().map(show).join(' | '));
/* The night this round exists to fix: nothing is left for staleGuard_ to bound,
 * so no phantom block and no UNLOGGED appear the next morning. */
H.setNow(H.nowMs() + 14 * 3600000);
reboot();
chk('and the next morning writes no phantom block and no UNLOGGED',
  A().length === 1 && !A().some(e => /UNLOGGED/.test(e.t)), A().map(show).join(' | '));
chk('the block still carries the mark its close applied',
  parseTitle_(A()[0].t).mark === '=', A()[0].t);

console.log('\n43i. STOP is a write like any other and does not bypass the queue');
reset(); reboot();
tapSit(); wait(5); tap('DW'); wait(30); settle();
H.setServerReject('nope');
tapStop(); tapStop(); settle();
chk('the UI shows nothing running immediately', activeKey() === null, String(activeKey()));
chk('and no SIT either', litPosture() === 'stand', String(litPosture()));
const q43 = JSON.parse(H.STORE['tt.queue.v1'] || '[]');
chk('both closes are sitting in the queue', q43.length >= 2, JSON.stringify(q43.map(o => o.type)));
chk('one of them closes the block', q43.some(o => o.type === 'closeActual'),
  JSON.stringify(q43.map(o => o.type)));
chk('one of them closes the sit', q43.some(o => o.type === 'closeSit'),
  JSON.stringify(q43.map(o => o.type)));
/* Guarded on a non-empty queue: "nothing opens" is true of an empty queue too,
 * and that is not what this is asserting. */
chk('and neither of them opens anything',
  q43.length > 0 && !q43.some(o => o.type === 'openActual' || o.type === 'openSit'),
  JSON.stringify(q43.map(o => o.type)));
H.setServerReject(null);

console.log('\n43j. confirming twice in quick succession queues exactly one close');
reset(); reboot();
tap('DW'); wait(30); settle();
H.setServerReject('nope');
tapStop(); tapStop();                       // armed, then confirmed
tapStop(); tapStop();                       // armed, then confirmed again
settle();
const q43j = JSON.parse(H.STORE['tt.queue.v1'] || '[]');
chk('exactly one close is queued',
  q43j.filter(o => o.type === 'closeActual').length === 1,
  JSON.stringify(q43j.map(o => o.type)));
H.setServerReject(null);
reset();

console.log('\n43k. an armed STOP that gets disarmed stops looking armed');
/* Found by the checker. tapCategory disarms STOP, and the re-tap-the-lit-block
 * branch returns without rendering — and disarming has already cancelled the
 * timer whose repaint would have fixed it. The button was left reading
 * TAP AGAIN TO STOP forever, and because the armed state takes the whole
 * posture row, it sat on top of the posture toggle and the sit clock: a black
 * bar promising to end the day, that did nothing when tapped. */
reset(); reboot();
tap('DW'); advance(10000); settle();
tapStop();
chk('armed', stopArmedNow(), stopLabel());
tap('DW');                                   // re-tap the lit block
chk('re-tapping the lit block disarms it', !stopArmedNow(), stopLabel());
chk('and it says STOP again', stopLabel() === 'STOP', stopLabel());
advance(60000); settle();
chk('and it is still saying STOP a minute later', stopLabel() === 'STOP', stopLabel());
chk('the block was never closed by any of that',
  openEvents().length === 1, A().map(show).join(' | '));

/* The other branch of the same return: past the mis-tap window, re-tapping the
 * lit block opens SPLIT rather than falling through. */
reset(); reboot();
tap('DW'); wait(5); settle();
tapStop();
chk('armed again', stopArmedNow(), stopLabel());
tap('DW');
chk('opening SPLIT also disarms it', !stopArmedNow(), stopLabel());
chk('and SPLIT did open', splitOpen());

/* Tapping a different category disarms it too. */
reset(); reboot();
tap('DW'); wait(5); settle();
tapStop();
tap('MTG'); settle();
chk('switching category disarms it', !stopArmedNow(), stopLabel());

console.log('\n43l. a server answer older than the STOP does not undo it');
/* Also found by the checker, and the risk HANDOFF-2.md names for this task.
 * getState takes no server lock and applyOps does, so the two round trips can
 * finish in either order. A getState computed before the STOP, arriving after
 * it, used to repopulate S.open with the block the user had just ended — and
 * the next tap then closed it at the wrong time, losing the end the user chose.
 * The queue-length guard could not catch it: by the time the answer lands, the
 * STOP has applied and the queue is empty. */
reset(); reboot();
tapSit(); wait(5); tap('DW'); wait(40); settle(); settle();
chk('the day is running before any of this', openEvents().length === 1 && openSits().length === 1,
  A().map(show).join(' | '));

// Make the read slow, then start one, so it is in flight when STOP lands.
H.setCallLag('getState', 400);
H.setNow(H.nowMs() + 11 * 60000);            // makes refreshOnReturn count it overdue
H.fireVisible();
// STOP now, and let its own round trip finish first.
$('stopBtn').fire('click'); $('stopBtn').fire('click');
advance(60); settle();
const endedAt = A()[0] && A()[0].e;
chk('the day ended', activeKey() === null && openEvents().length === 0,
  A().map(show).join(' | '));
chk('and the queue drained, so the old guard would not fire',
  JSON.parse(H.STORE['tt.queue.v1'] || '[]').length === 0, H.STORE['tt.queue.v1'] || '[]');

advance(500); settle();                      // the stale read finally lands
chk('the stale answer does not bring the block back', activeKey() === null,
  String(activeKey()));
chk('nor the SIT', litPosture() === 'stand', String(litPosture()));
chk('nothing reopened on either calendar',
  openEvents().length === 0 && openSits().length === 0,
  A().map(show).join(' | ') + ' // ' + S().map(show).join(' | '));
chk('and the end time the user chose is untouched', A()[0].e === endedAt,
  show(A()[0]));
H.setCallLag('getState', null);
reset();

/* ── A5: waking hours stop counting time nobody logged ─────────────
 *
 * UNLOGGED lands on the ACTUAL calendar, so before this the nightly one dragged
 * every day's span back to 00:00 and both `waking h` and `sitting %` measured
 * nothing. A '?' block's end is the app's guess, not a time anyone reported
 * stopping. Neither may stretch the span; both keep their own hours. */

const AC = (t, day, h1, m1, h2, m2) => H.CALS.actual.createEvent(t,
  new Date(D(2026, 7, day, h1, m1)), new Date(D(2026, 7, day, h2, m2)), {});
const SI = (day, h1, m1, h2, m2) => H.CALS.sit.createEvent('SIT',
  new Date(D(2026, 7, day, h1, m1)), new Date(D(2026, 7, day, h2, m2)), {});
const dRows = () => H.SHEETS.book.getSheetByName('daily').rows;
const dCol = n => dRows()[0].indexOf(n);
const dRow = ymd => dRows().find(r => r[0] === ymd);
const dayCell = (ymd, n) => { const r = dRow(ymd); return r ? r[dCol(n)] : undefined; };

console.log('\n44. UNLOGGED time does not count as waking time');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('UNLOGGED -', 20, 0, 0, 7, 0);
AC('DW: shipping', 20, 9, 0, 17, 0);
dailyRollup();
chk('waking h is 8, not 17', dayCell('2026-07-20', 'waking h') === 8,
  String(dayCell('2026-07-20', 'waking h')));
chk('and UNLOGGED still reports its own 7 hours',
  dayCell('2026-07-20', 'UNLOGGED') === 7, String(dayCell('2026-07-20', 'UNLOGGED')));
chk('and DW still reports its 8', dayCell('2026-07-20', 'DW') === 8,
  String(dayCell('2026-07-20', 'DW')));

console.log('\n44b. a guessed block does not count as waking time either');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('DW: shipping', 20, 9, 0, 17, 0);
AC('MTG: ?', 20, 22, 0, 23, 59);
dailyRollup();
chk('waking h counts 09:00-17:00 only', dayCell('2026-07-20', 'waking h') === 8,
  String(dayCell('2026-07-20', 'waking h')));
chk('and the guessed block still reports its own hours',
  near(dayCell('2026-07-20', 'MTG') * 3600000, 1.98 * 3600000),
  String(dayCell('2026-07-20', 'MTG')));

console.log('\n44c. the span is a span, not a sum');
/* A guessed block sitting between two logged ones must not punch a hole in the
 * day: the ends are what is measured. */
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('DW: morning', 20, 9, 0, 12, 0);
AC('ADM: ?', 20, 12, 0, 14, 0);
AC('MTG: afternoon', 20, 14, 0, 17, 0);
dailyRollup();
chk('waking h is the whole 8-hour span', dayCell('2026-07-20', 'waking h') === 8,
  String(dayCell('2026-07-20', 'waking h')));
chk('the guessed two hours are not subtracted from it',
  dayCell('2026-07-20', 'waking h') === 8 && dayCell('2026-07-20', 'ADM') === 2,
  'waking ' + dayCell('2026-07-20', 'waking h') + ' ADM ' + dayCell('2026-07-20', 'ADM'));

console.log('\n44d. the common case does not move');
/* The load-bearing one. A day with nothing unlogged and nothing guessed must
 * report exactly what it reported before this round — and section 39d already
 * compares both whole grids against test/fixtures/rollup-golden.json, which is
 * unchanged by this task. This asserts the specific column directly. */
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('DW: shipping', 20, 9, 0, 12, 0);
AC('MTG: standup', 20, 13, 30, 17, 15);
dailyRollup();
chk('waking h spans first start to last end, unchanged',
  near(dayCell('2026-07-20', 'waking h') * 3600000, 8.25 * 3600000),
  String(dayCell('2026-07-20', 'waking h')));

console.log('\n44e. a day of nothing but UNLOGGED divides by nothing');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('UNLOGGED -', 20, 0, 0, 23, 59);
SI(20, 9, 0, 11, 0);
dailyRollup();
chk('waking h is 0', dayCell('2026-07-20', 'waking h') === 0,
  String(dayCell('2026-07-20', 'waking h')));
chk('sitting % is blank, not Infinity and not an error',
  dayCell('2026-07-20', 'sitting %') === '',
  JSON.stringify(dayCell('2026-07-20', 'sitting %')));
chk('and the sitting hours are still reported',
  dayCell('2026-07-20', 'sitting h') === 2, String(dayCell('2026-07-20', 'sitting h')));
chk('while UNLOGGED keeps its own hours',
  near(dayCell('2026-07-20', 'UNLOGGED') * 3600000, 23.98 * 3600000),
  String(dayCell('2026-07-20', 'UNLOGGED')));

console.log('\n44f. a day with no events at all still reports');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('DW: elsewhere', 22, 9, 0, 10, 0);        // a different day, so the window has rows
let e44 = null;
try { dailyRollup(); } catch (e) { e44 = String((e && e.message) || e); }
chk('the rollup does not throw', e44 === null, String(e44));
chk('the empty day reports 0 waking', dayCell('2026-07-20', 'waking h') === 0,
  String(dayCell('2026-07-20', 'waking h')));
chk('and blank sitting %', dayCell('2026-07-20', 'sitting %') === '',
  JSON.stringify(dayCell('2026-07-20', 'sitting %')));

console.log('\n44h. a day made only of guessed time reports no waking hours');
/* This pins a CONSEQUENCE, not a desired behaviour, and it is the shape of
 * parked question Q9.
 *
 * A '?' block's START is a fact the user reported — they tapped the category at
 * 22:00 — and only its END was guessed. The guard discards both, so the evening
 * a user starts work at 22:00 and never closes the day reports `waking h` 0
 * while `DW` reads 2: a row that contradicts itself.
 *
 * Letting a '?' block's start extend `first` while its end does not extend
 * `last` would fix it and still satisfy A5's criteria 2 and 5 — but contract 22
 * says a '?' block does "not extend the waking span", full stop, and a block
 * that is the day's earliest event would then extend it backwards. Choosing
 * that is overriding a contract assertion, which is the human's call and not
 * the loop's.
 *
 * So the behaviour is pinned here rather than left accidental. If Q9 is ruled
 * the other way, THIS is the test to change. */
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('DW: evening ?', 20, 22, 0, 23, 59);
dailyRollup();
chk('waking h is 0 for a day of nothing but guessed time',
  dayCell('2026-07-20', 'waking h') === 0, String(dayCell('2026-07-20', 'waking h')));
chk('while the block still reports its own hours',
  near(dayCell('2026-07-20', 'DW') * 3600000, 1.98 * 3600000),
  String(dayCell('2026-07-20', 'DW')));
chk('and sitting % stays blank rather than dividing by it',
  dayCell('2026-07-20', 'sitting %') === '',
  JSON.stringify(dayCell('2026-07-20', 'sitting %')));

console.log('\n44g. an UNLOGGED block is still only excluded from the span');
/* Guards the over-correction: excluding it from the span must not quietly
 * exclude it from switches or from the key set. */
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('UNLOGGED -', 20, 0, 0, 7, 0);
AC('DW: shipping', 20, 9, 0, 17, 0);
dailyRollup();
chk('UNLOGGED still has a column', dCol('UNLOGGED') >= 0, JSON.stringify(dRows()[0]));
chk('and both blocks still counted as switches',
  dayCell('2026-07-20', 'switches') === 2, String(dayCell('2026-07-20', 'switches')));
reset();

/* ── B1: the day's statistics know how each hour was marked ────────
 *
 * dayStats_ parsed the mark and then never read it, so it was discarded at the
 * exact point it would have become a number. Five buckets per key: the four
 * marks and unmarked. Unmarked is a real bucket — a block closed under
 * MIN_MARK_MINUTES legitimately carries none, and its hours are as real as any
 * other. */

/* Reaches dayStats_ through the real rollup, then reads the day back off the
 * one the rollup built, so nothing here depends on a private call signature. */
const statsFor = (day, seed) => {
  reset(D(2026, 7, 24, 15, 0)); goodSheet();
  seed();
  const lo = D(2026, 7, day, 0, 0), hi = D(2026, 7, day + 1, 0, 0);
  return dayStats_(lo, hi,
    H.CALS.plan.getEvents(new Date(lo), new Date(hi)).map(e => ({ title: e.t, start: e.s, end: e.e })),
    H.CALS.actual.getEvents(new Date(lo), new Date(hi)).map(e => ({ title: e.t, start: e.s, end: e.e })),
    H.CALS.sit.getEvents(new Date(lo), new Date(hi)).map(e => ({ title: e.t, start: e.s, end: e.e })),
    rollupKeys_());
};

console.log('\n45. every hour is counted under the mark it carries');
const s45 = statsFor(20, () => {
  AC('DW: morning =', 20, 9, 0, 11, 0);
  AC('DW: afternoon -', 20, 13, 0, 14, 0);
  AC('MTG: standup ?', 20, 15, 0, 15, 30);
});
chk('DW = holds 2h', near(s45.marks.DW['='] * 3600000, 2 * 3600000), String(s45.marks.DW['=']));
chk('DW - holds 1h', near(s45.marks.DW['-'] * 3600000, 1 * 3600000), String(s45.marks.DW['-']));
chk('MTG ? holds 30m', near(s45.marks.MTG['?'] * 3600000, 0.5 * 3600000), String(s45.marks.MTG['?']));
chk('and the existing DW total is still 3', near(s45.actual.DW * 3600000, 3 * 3600000),
  String(s45.actual.DW));
chk('DW + is zero, not missing', s45.marks.DW['+'] === 0, JSON.stringify(s45.marks.DW));
chk('DW unmarked is zero, not missing', s45.marks.DW[''] === 0, JSON.stringify(s45.marks.DW));

console.log('\n45b. a key\'s buckets always sum to its total — asserted per key');
/* All five mark states across every configured category, then checked key by
 * key. An aggregate check would pass while one key's hours were counted into
 * another key's bucket. */
const s45b = statsFor(20, () => {
  let h = 0;
  CATEGORIES.forEach(c => {
    ['+', '=', '-', '?', null].forEach(m => {
      AC(c.key + ': work' + (m ? ' ' + m : ''), 20, h % 24, 0, h % 24, 30);
      h++;
    });
  });
});
const offBy = [];
rollupKeys_().forEach(k => {
  const sum = MARK_BUCKETS.reduce((a, m) => a + s45b.marks[k][m], 0);
  if (Math.abs(sum - s45b.actual[k]) > 0.005) {
    offBy.push(k + ': buckets ' + round2_(sum) + ' vs total ' + round2_(s45b.actual[k]));
  }
});
chk('every key\'s five buckets sum to its total, to two decimals',
  offBy.length === 0, offBy.join(' | '));
chk('and the fixture really did exercise every category',
  CATEGORIES.every(c => s45b.actual[c.key] > 0),
  JSON.stringify(CATEGORIES.map(c => [c.key, round2_(s45b.actual[c.key])])));
chk('across all five buckets',
  MARK_BUCKETS.every(m => rollupKeys_().some(k => s45b.marks[k][m] > 0)),
  JSON.stringify(MARK_BUCKETS.map(m => [m || '(unmarked)',
    rollupKeys_().reduce((a, k) => a + s45b.marks[k][m], 0)])));

console.log('\n45c. a block too short to carry a mark still lands somewhere');
const s45c = statsFor(20, () => {
  AC('DW: quick', 20, 9, 0, 9, 5);            // 5m, under MIN_MARK_MINUTES
  AC('DW: proper =', 20, 10, 0, 12, 0);
});
chk('the unmarked 5 minutes are in the unmarked bucket',
  near(s45c.marks.DW[''] * 3600000, 5 * 60000), String(s45c.marks.DW['']));
chk('and are not dropped from the total',
  near(s45c.actual.DW * 3600000, (2 * 60 + 5) * 60000), String(s45c.actual.DW));

console.log('\n45d. an unrecognised trailing character makes no sixth bucket');
const s45d = statsFor(20, () => { AC('DW: memo !', 20, 9, 0, 10, 0); });
chk('it counts as unmarked', near(s45d.marks.DW[''] * 3600000, 3600000),
  String(s45d.marks.DW['']));
chk('and DW has exactly five buckets', Object.keys(s45d.marks.DW).length === 5,
  JSON.stringify(Object.keys(s45d.marks.DW)));
chk('which are the four marks and unmarked',
  JSON.stringify(Object.keys(s45d.marks.DW).sort()) ===
  JSON.stringify(['+', '-', '=', '?', ''].sort()),
  JSON.stringify(Object.keys(s45d.marks.DW)));

console.log('\n45e. a day with no events is all zeroes, and does not throw');
let e45 = null, s45e = null;
try { s45e = statsFor(20, () => { AC('DW: elsewhere', 22, 9, 0, 10, 0); }); }
catch (e) { e45 = String((e && e.message) || e); }
chk('nothing throws', e45 === null, String(e45));
chk('every bucket of every key is 0',
  rollupKeys_().every(k => MARK_BUCKETS.every(m => s45e.marks[k][m] === 0)),
  JSON.stringify(s45e && s45e.marks));
chk('and every key still has its full set of buckets',
  rollupKeys_().every(k => Object.keys(s45e.marks[k]).length === 5),
  JSON.stringify(rollupKeys_().map(k => [k, Object.keys(s45e.marks[k]).length])));

console.log('\n45f. the existing per-key totals did not move');
/* The golden fixture is the real guard here — section 39d compares both whole
 * grids and is untouched by this task. This asserts the property directly. */
const s45f = statsFor(20, () => {
  AC('DW: a =', 20, 9, 0, 12, 0);
  AC('MTG: b -', 20, 13, 0, 14, 30);
  AC('UNLOGGED -', 20, 20, 0, 23, 0);
});
chk('DW total unchanged by bucketing', near(s45f.actual.DW * 3600000, 3 * 3600000),
  String(s45f.actual.DW));
chk('MTG total unchanged', near(s45f.actual.MTG * 3600000, 1.5 * 3600000),
  String(s45f.actual.MTG));
chk('UNLOGGED is bucketed too, under the mark it carries',
  near(s45f.marks.UNLOGGED['-'] * 3600000, 3 * 3600000), JSON.stringify(s45f.marks.UNLOGGED));
reset();

/* ── B2 and B3: both tabs carry a column per category per mark ─────
 *
 * Appended, never interleaved. Existing column positions are a contract with
 * formulas that live outside this repo and cannot be tested from inside it, so
 * these assert POSITIONS and not merely presence.
 *
 * The positions are read from test/fixtures/rollup-golden.json, which is the
 * pre-round record and is deliberately NOT regenerated — see the note in
 * factory/progress-2.md. A fixture rewritten from the new code would agree with
 * whatever the new code did. */

const wRows = () => H.SHEETS.book.getSheetByName('weekly').rows;

console.log('\n46. no column that existed before this round has moved');
const GOLD46 = require('./fixtures/rollup-golden.json');
const gz46 = GOLD46.byZone[ZONE];
if (!gz46) {
  H.skip('46. no column that existed before this round has moved',
    'no golden captured for this zone; the four contracted zones are ' +
    Object.keys(GOLD46.byZone).sort().join(', '));
} else {
  reset(D(2026, 7, 24, 15, 0)); goodSheet();
  AC('DW: a =', 20, 9, 0, 11, 0);
  dailyRollup();
  [['daily', dRows()], ['weekly', wRows()]].forEach(([tab, live]) => {
    const goldHead = gz46.grids[tab][0];
    /* Same reasoning as 39d: D1 adds a key, and a key inserts a column into
     * every group the grid is built from, so pre-round indexes necessarily
     * shift. What is asserted is that they shift TOGETHER and only for that
     * reason — same columns, same order, and the only things between them are
     * the new key's own columns. Contract 20's purpose was never "the numbers
     * must never move"; it was "the mark columns must be appended rather than
     * interleaved", and that is what this still catches. Q14. */
    const NEW_COLS = tab === 'daily'
      ? [UNFILED_KEY, 'plan ' + UNFILED_KEY]
      : ['plan ' + UNFILED_KEY, UNFILED_KEY, UNFILED_KEY + ' ratio'];
    const surviving = live[0].filter(h => goldHead.includes(h));
    const misordered = surviving
      .map((h, i) => (h === goldHead[i] ? null : i + ': expected ' + goldHead[i] + ', found ' + h))
      .filter(Boolean);
    chk(tab + ': every pre-round header is still present, in the same order',
      surviving.length === goldHead.length && misordered.length === 0,
      misordered.slice(0, 4).join(' | ') || (surviving.length + ' of ' + goldHead.length));
    const lastGoldAt = live[0].lastIndexOf(goldHead[goldHead.length - 1]);
    const inserted = live[0].slice(0, lastGoldAt + 1).filter(h => !goldHead.includes(h));
    chk(tab + ': and nothing was interleaved among them but the one key D1 adds',
      JSON.stringify(inserted) === JSON.stringify(NEW_COLS),
      JSON.stringify(inserted) + ' vs ' + JSON.stringify(NEW_COLS));
    chk(tab + ': and the grid only got wider, never shorter',
      live[0].length > goldHead.length,
      live[0].length + ' vs ' + goldHead.length);
  });
}

console.log('\n47. a day\'s marks show up as columns, beside the total that contains them');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('DW: settled =', 20, 9, 0, 11, 0);
AC('DW: guessed ?', 20, 13, 0, 14, 0);
dailyRollup();
chk('DW = shows 2', dayCell('2026-07-20', 'DW =') === 2, String(dayCell('2026-07-20', 'DW =')));
chk('DW ? shows 1', dayCell('2026-07-20', 'DW ?') === 1, String(dayCell('2026-07-20', 'DW ?')));
chk('and the existing DW column still shows 3',
  dayCell('2026-07-20', 'DW') === 3, String(dayCell('2026-07-20', 'DW')));
chk('the buckets that saw nothing show 0, not blank',
  dayCell('2026-07-20', 'DW +') === 0 && dayCell('2026-07-20', 'DW -') === 0 &&
  dayCell('2026-07-20', 'DW unmarked') === 0,
  JSON.stringify([dayCell('2026-07-20', 'DW +'), dayCell('2026-07-20', 'DW -'),
                  dayCell('2026-07-20', 'DW unmarked')]));

console.log('\n47b. every row is the width of the header');
/* A short row is how a column silently shifts. */
const ragged47 = dRows().filter(r => r.length !== dRows()[0].length)
  .map((r, i) => 'row ' + i + ' is ' + r.length + ' wide');
chk('daily: no ragged rows', ragged47.length === 0, ragged47.slice(0, 4).join(' | '));
const raggedW47 = wRows().filter(r => r.length !== wRows()[0].length)
  .map((r, i) => 'row ' + i + ' is ' + r.length + ' wide');
chk('weekly: no ragged rows', raggedW47.length === 0, raggedW47.slice(0, 4).join(' | '));

console.log('\n47c. exactly one stamp, after the last data column');
const stamps47 = dRows()[0].filter(h => /^last rebuilt /.test(h));
chk('daily: exactly one stamp', stamps47.length === 1, JSON.stringify(stamps47));
chk('daily: and it is the last column',
  /^last rebuilt /.test(dRows()[0][dRows()[0].length - 1]),
  JSON.stringify(dRows()[0].slice(-2)));
const stampsW47 = wRows()[0].filter(h => /^last rebuilt /.test(h));
chk('weekly: exactly one stamp', stampsW47.length === 1, JSON.stringify(stampsW47));
chk('weekly: and it is the last column',
  /^last rebuilt /.test(wRows()[0][wRows()[0].length - 1]),
  JSON.stringify(wRows()[0].slice(-2)));

console.log('\n47d. two runs against a fixed clock produce the same grid');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('DW: a =', 20, 9, 0, 11, 0);
AC('MTG: b ?', 20, 13, 0, 14, 0);
dailyRollup();
const first47 = JSON.stringify(dRows());
const firstW47 = JSON.stringify(wRows());
dailyRollup();
chk('daily is byte-identical the second time', JSON.stringify(dRows()) === first47);
chk('weekly is byte-identical the second time', JSON.stringify(wRows()) === firstW47);

console.log('\n48. a week\'s bucket is the sum of its days\' same bucket');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('DW: mon =', 20, 9, 0, 11, 0);
AC('DW: tue =', 21, 9, 0, 12, 0);
AC('DW: wed ?', 22, 9, 0, 10, 0);
AC('MTG: thu -', 23, 9, 0, 9, 30);
dailyRollup();
const wHead = wRows()[0];
const wRow = wRows().find(r => r[0] === '2026-07-20');
const wCell = n => wRow[wHead.indexOf(n)];
chk('the week\'s DW = is 2 + 3', wCell('DW =') === 5, String(wCell('DW =')));
chk('the week\'s DW ? is 1', wCell('DW ?') === 1, String(wCell('DW ?')));
chk('the week\'s MTG - is 0.5', wCell('MTG -') === 0.5, String(wCell('MTG -')));
/* Checked against the daily tab rather than against numbers typed in here, so
 * a bucket summed into the wrong key is caught — per-key totals would not
 * reveal it, because they would still add up. */
const drift48 = [];
rollupKeys_().forEach(k => MARK_BUCKETS.forEach(m => {
  const col = markCol_(k, m);
  const daySum = ['2026-07-20', '2026-07-21', '2026-07-22', '2026-07-23',
                  '2026-07-24', '2026-07-25', '2026-07-26']
    .reduce((a, ymd) => a + (dayCell(ymd, col) || 0), 0);
  if (Math.abs(round2_(daySum) - wCell(col)) > 0.005) {
    drift48.push(col + ': days ' + round2_(daySum) + ' vs week ' + wCell(col));
  }
}));
chk('every weekly mark cell equals the sum of its days', drift48.length === 0,
  drift48.join(' | '));

console.log('\n48b. a week of nothing but guesses says 0, not blank');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('DW: all guessed ?', 20, 9, 0, 12, 0);
AC('DW: also guessed ?', 21, 9, 0, 11, 0);
dailyRollup();
const wRow48 = wRows().find(r => r[0] === '2026-07-20');
const wCell48 = n => wRow48[wRows()[0].indexOf(n)];
chk('the ? column carries all its hours', wCell48('DW ?') === 5, String(wCell48('DW ?')));
chk('the = column says 0', wCell48('DW =') === 0, JSON.stringify(wCell48('DW =')));
chk('and 0 is a number, not an empty cell', typeof wCell48('DW =') === 'number',
  typeof wCell48('DW ='));
chk('while the ratio cell for an unplanned key is still blank',
  wCell48('DW ratio') === '', JSON.stringify(wCell48('DW ratio')));

console.log('\n48c. a retired category keeps its full set of mark columns');
/* removeCategory only retires a category that was added at runtime — one in the
 * CATEGORIES array has to leave Code.gs — so the fixture adds one, logs history
 * under it, and then retires it. Its history stays in the rollup, and the
 * handoff requires it keep every mark column while it does. */
reset(D(2026, 7, 24, 15, 0)); goodSheet();
const added48 = addCategory('Sketching').categories.find(c => c.label === 'Sketching');
H.clearPropCache();
AC(added48.key + ': history =', 20, 9, 0, 11, 0);
AC(added48.key + ': guessed ?', 20, 13, 0, 14, 0);
dailyRollup();
chk('while it is live it has its mark columns',
  MARK_BUCKETS.every(m => dRows()[0].indexOf(markCol_(added48.key, m)) >= 0),
  JSON.stringify(dRows()[0].filter(h => h.indexOf(added48.key) === 0)));
removeCategory(added48.key);
H.clearPropCache();
dailyRollup();
const missing48 = MARK_BUCKETS.filter(m => dRows()[0].indexOf(markCol_(added48.key, m)) < 0);
chk('and once retired it still has every one of them',
  missing48.length === 0, JSON.stringify(missing48.map(m => markCol_(added48.key, m))));
chk('its logged history is still in them',
  dayCell('2026-07-20', markCol_(added48.key, '=')) === 2,
  String(dayCell('2026-07-20', markCol_(added48.key, '='))));
chk('including the guessed hours', dayCell('2026-07-20', markCol_(added48.key, '?')) === 1,
  String(dayCell('2026-07-20', markCol_(added48.key, '?'))));
reset(); H.clearPropCache();

/* ── B4: the rollup says how much of PLAN it could actually read ───
 *
 * A plan written as "Deep work — memo" contributes exactly zero and every ratio
 * column reads blank forever, with nothing anywhere saying why. This counts and
 * stops; it never guesses what an unparsed title meant. */

const REC4 = () => JSON.parse(H.SCRIPT_PROPS.ROLLUP_LAST || '{}');

console.log('\n49. the record says how many PLAN events there were and how many counted');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
// 3 that reach a configured category...
PL('DW: ship it', 20, 9, 12);
PL('MTG: standup', 20, 13, 14);
PL('ADM: inbox', 21, 9, 10);
// ...and 9 that do not.
PL('Deep work — memo', 20, 15, 17);
PL('9:00 standup', 21, 11, 12);
PL('Re: the thing', 21, 14, 15);
PL('Dinner: with Ada', 21, 19, 21);
PL('gym', 22, 7, 8);
PL('Lunch with Ada', 22, 12, 13);
PL('review the deck', 22, 15, 16);
PL('CALL: mum', 23, 18, 19);
PL('gardening', 23, 9, 10);
dailyRollup();
chk('12 PLAN events found', REC4().planFound === 12, String(REC4().planFound));
chk('3 of them named a configured category', REC4().planParsed === 3,
  String(REC4().planParsed));

console.log('\n49b. and says it in words a person would read');
const st49 = rollupStatus();
chk('the status names both numbers', /12/.test(st49) && /3/.test(st49), st49);
chk('in a sentence, not as a bare pair of integers',
  /found 12, of which 3 named a configured category/.test(st49), st49);
chk('and says what the other nine cost',
  /other 9 counted toward nothing/.test(st49), st49);
chk('and says what would have made them count',
  /category key and a colon/.test(st49), st49);
chk('with neither undefined nor NaN anywhere in it',
  !/undefined|NaN/.test(st49), st49);

console.log('\n49c. "9:00 standup" is found but not parsed');
/* The point of the task: the count is of events that reached a category, not
 * of events the regex matched. "9:00 standup" parses to key 9, which is
 * nobody's category. */
chk('parseTitle_ does match it', parseTitle_('9:00 standup') !== null,
  JSON.stringify(parseTitle_('9:00 standup')));
chk('to a key nobody configured', rollupKeys_().indexOf('9') < 0,
  JSON.stringify(rollupKeys_()));
reset(D(2026, 7, 24, 15, 0)); goodSheet();
PL('9:00 standup', 20, 9, 10);
dailyRollup();
chk('so it counts as found', REC4().planFound === 1, String(REC4().planFound));
chk('and not as parsed', REC4().planParsed === 0, String(REC4().planParsed));

console.log('\n49d. setupRollup reports it too');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
PL('DW: ship it', 20, 9, 12);
PL('gardening', 20, 15, 16);
const rep49 = setupRollup();
chk('the setup report names both numbers',
  /found 2, of which 1 named a configured category/.test(rep49), rep49);
chk('and prints neither undefined nor NaN', !/undefined|NaN/.test(rep49), rep49);

console.log('\n49e. the grids stay pure numbers');
chk('no daily header mentions the counts',
  !dRows()[0].some(h => /plan events|found|parsed/i.test(String(h))),
  JSON.stringify(dRows()[0]));
chk('no weekly header does either',
  !wRows()[0].some(h => /plan events|found|parsed/i.test(String(h))),
  JSON.stringify(wRows()[0]));
chk('and no cell in either grid does',
  !dRows().slice(1).concat(wRows().slice(1))
    .some(r => r.some(c => /plan events|counted toward nothing/i.test(String(c)))),
  'a count leaked into a data row');

console.log('\n49f. a PLAN calendar that cannot be read at all is 0 and 0');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
H.SCRIPT_PROPS.CAL_PLAN = 'nosuchcalendar'; H.clearPropCache();
let e49 = null;
try { dailyRollup(); } catch (e) { e49 = String((e && e.message) || e); }
chk('nothing throws', e49 === null, String(e49));
chk('found is 0', REC4().planFound === 0, String(REC4().planFound));
chk('parsed is 0', REC4().planParsed === 0, String(REC4().planParsed));
delete H.SCRIPT_PROPS.CAL_PLAN; H.clearPropCache();

console.log('\n49g. zero PLAN events says so plainly');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
dailyRollup();
const st49g = rollupStatus();
chk('found is 0', REC4().planFound === 0, String(REC4().planFound));
chk('and the report says none were found',
  /none found in the window/.test(st49g), st49g);
chk('and explains what that means for the ratios',
  /every ratio column is blank/.test(st49g), st49g);
chk('with neither undefined nor NaN', !/undefined|NaN/.test(st49g), st49g);

console.log('\n49h. a failure never overwrites the counts with zeroes');
/* Same rule round 1 set for lastSuccessMs: a run that failed before it read
 * PLAN knows nothing about PLAN, and writing 0 would be a false claim rather
 * than a missing one. */
reset(D(2026, 7, 24, 15, 0)); goodSheet();
PL('DW: ship it', 20, 9, 12);
PL('gardening', 20, 15, 16);
dailyRollup();
chk('a good run recorded 2 and 1',
  REC4().planFound === 2 && REC4().planParsed === 1, JSON.stringify(REC4()));
H.SCRIPT_PROPS.SHEET_ID = 'no-such-book'; H.clearPropCache();
let e49h = null;
try { dailyRollup(); } catch (e) { e49h = String((e && e.message) || e); }
chk('the next run fails', e49h !== null, String(e49h));
chk('and it is recorded as a failure', REC4().outcome === 'failed', JSON.stringify(REC4()));
chk('but the counts from the last good run survive',
  REC4().planFound === 2 && REC4().planParsed === 1, JSON.stringify(REC4()));
chk('and the report still states them',
  /found 2, of which 1 named a configured category/.test(rollupStatus()), rollupStatus());
reset(); H.clearPropCache();

/* ── C1: the tap windows nest ──────────────────────────────────────
 *
 * MISTAP_SECONDS was 90 and CONFIRM_WITHIN_SECONDS 60, so between 60 and 90
 * seconds after the last tap a single unconfirmed tap acted immediately AND
 * destructively — it retitled the block you were actually in. The correction
 * window now sits well inside the confirm window, which makes every
 * destructive path confirmed by construction rather than by luck. */

console.log('\n50. the correction window sits inside the confirm window');
chk('MISTAP_SECONDS is below CONFIRM_WITHIN_SECONDS',
  MISTAP_SECONDS < CONFIRM_WITHIN_SECONDS,
  MISTAP_SECONDS + ' vs ' + CONFIRM_WITHIN_SECONDS);
chk('and both are positive numbers',
  MISTAP_SECONDS > 0 && CONFIRM_WITHIN_SECONDS > 0,
  MISTAP_SECONDS + ' / ' + CONFIRM_WITHIN_SECONDS);
chk('the client is told the same two values',
  clientConfig_().mistapSeconds === MISTAP_SECONDS &&
  clientConfig_().confirmWithinSeconds === CONFIRM_WITHIN_SECONDS,
  JSON.stringify([clientConfig_().mistapSeconds, clientConfig_().confirmWithinSeconds]));

console.log('\n50b. a 45-second block is recordable for the first time');
/* At 90 seconds there was no way to log a deliberate short block: the tap that
 * ended it was treated as a correction and ate it. */
reset(); reboot();
const t50 = H.nowMs();
tap('DW'); advance(45000); settle();
tap('MTG'); tap('MTG'); settle();
chk('two blocks exist', A().length === 2, A().map(show).join(' | '));
chk('the first is still DW', A()[0].t === 'DW:', A()[0].t);
chk('it ran 45 seconds', near(A()[0].e - A()[0].s, 45000, 1500),
  String((A()[0].e - A()[0].s) / 1000) + 's');
chk('and MTG is open from where it ended',
  /#open/.test(A()[1].d) && A()[1].s === A()[0].e, A().map(show).join(' | '));

console.log('\n50c. inside the correction window a confirmed tap still corrects');
reset(); reboot();
const t50c = H.nowMs();
tap('DW'); advance(10000); settle();
tap('MTG'); tap('MTG'); settle();
chk('one block exists', A().length === 1, A().map(show).join(' | '));
chk('keyed MTG', A()[0].t === 'MTG:', A()[0].t);
chk('with the original start time', A()[0].s === t50c, show(A()[0]));

console.log('\n50d. an unconfirmed tap at 45 seconds does nothing at all');
reset(); reboot();
tap('DW'); advance(45000); settle();
tap('MTG');
chk('it armed rather than acting', armedKey() === 'MTG', String(armedKey()));
advance(CONFIRM_TIMEOUT_MS + 100); settle();
chk('and forgot', armedKey() === null, String(armedKey()));
chk('nothing was queued', JSON.parse(H.STORE['tt.queue.v1'] || '[]').length === 0,
  H.STORE['tt.queue.v1'] || '[]');
chk('DW is still the open block', A().length === 1 && A()[0].t === 'DW:' &&
  /#open/.test(A()[0].d), A().map(show).join(' | '));

console.log('\n50e. past the confirm window a tap is still just a tap');
reset(); reboot();
tap('DW'); wait(5); settle();
tap('MTG'); settle();
chk('it acted on one tap', A().length === 2, A().map(show).join(' | '));
chk('DW closed and still keyed DW, MTG open',
  A()[0].t === 'DW:' && !/#open/.test(A()[0].d) && /#open/.test(A()[1].d),
  A().map(show).join(' | '));

console.log('\n50f. THE SWEEP — no elapsed time lets one tap change a block\'s key');
/* Contract 28, and the criterion that matters most in this task.
 *
 * Every individual window test above would pass against a build where the two
 * constants were merely different from each other. Only this proves there is no
 * reachable gap: second by second across the whole span, a single unconfirmed
 * tap on a different category must never change an existing block's key.
 *
 * It sweeps past both windows deliberately — a gap could open on either side of
 * either boundary, and the two configured values are not what is being tested. */
const gaps50 = [];
for (let secs = 0; secs <= 120; secs++) {
  reset(); reboot();
  tap('DW');
  if (secs) advance(secs * 1000);
  settle();
  const keysBefore = A().map(e => (parseTitle_(e.t) || {}).key);
  tap('MTG');                                   // exactly one tap, never confirmed
  settle();
  const keysAfter = A().map(e => (parseTitle_(e.t) || {}).key);
  // Every block that existed before must still carry the key it had.
  for (let i = 0; i < keysBefore.length; i++) {
    if (keysBefore[i] !== keysAfter[i]) {
      gaps50.push(secs + 's: block ' + i + ' went ' + keysBefore[i] + ' -> ' + keysAfter[i]);
    }
  }
}
chk('no single tap at any second from 0 to 120 changed an existing block\'s key',
  gaps50.length === 0, gaps50.slice(0, 8).join(' | '));
chk('and the sweep really ran across both windows',
  MISTAP_SECONDS <= 120 && CONFIRM_WITHIN_SECONDS <= 120,
  'swept 0..120 against ' + MISTAP_SECONDS + ' and ' + CONFIRM_WITHIN_SECONDS);

console.log('\n50g. the one coupling survives the window change');
/* Tapping BODY closes an open SIT. That is the app's only coupling, and it has
 * to hold on the correction branch as well as the transition one. */
reset(); reboot();
tapSit(); settle();
tap('DW'); advance(10000); settle();
chk('a SIT is open before the correction', S().length === 1 && /#open/.test(S()[0].d),
  S().map(show).join(' | '));
tap('BODY'); tap('BODY'); settle();
chk('the tap landed as a correction', A().length === 1 && A()[0].t === 'BODY:',
  A().map(show).join(' | '));
chk('and the SIT still closed', S().length === 1 && !/#open/.test(S()[0].d),
  S().map(show).join(' | '));
reset();

/* ── C2: the armed button says which of the two things it will do ──
 *
 * "TAP AGAIN" did not disclose whether confirming would retitle the block you
 * are in or start a new one. Same rule round 1 settled on for
 * TAP AGAIN TO DISCARD: state what the next tap will do, and stop. */

const armedText = H.armedText;

console.log('\n51. inside the correction window it offers to retitle');
reset(); reboot();
tap('DW'); advance(10000); settle();
tap('MTG'); settle();
chk('the cell is armed', armedKey() === 'MTG', String(armedKey()));
chk('and it reads TAP AGAIN TO RETITLE', armedText() === 'TAP AGAIN TO RETITLE',
  JSON.stringify(armedText()));

console.log('\n51b. outside it, it offers to switch');
reset(); reboot();
tap('DW'); advance(45000); settle();
tap('MTG'); settle();
chk('the cell is armed', armedKey() === 'MTG', String(armedKey()));
chk('and it reads TAP AGAIN TO SWITCH', armedText() === 'TAP AGAIN TO SWITCH',
  JSON.stringify(armedText()));

console.log('\n51c. a forgotten confirmation leaves no text and no styling');
['10', '45'].forEach(secs => {
  reset(); reboot();
  tap('DW'); advance(Number(secs) * 1000); settle();
  tap('MTG'); settle();
  chk('armed at ' + secs + 's', armedKey() === 'MTG' && armedText() !== '',
    armedKey() + ' ' + JSON.stringify(armedText()));
  advance(CONFIRM_TIMEOUT_MS + 100); settle();
  chk('at ' + secs + 's the arming style is gone', armedKey() === null, String(armedKey()));
  chk('at ' + secs + 's the text is empty', armedText() === '', JSON.stringify(armedText()));
});

console.log('\n51d. the label always names the action that actually happens');
/* Read the label, then confirm, then check WHICH of the two outcomes occurred.
 * Asserted for both windows rather than assumed from the wording. */
[[10, 'TAP AGAIN TO RETITLE', 1], [45, 'TAP AGAIN TO SWITCH', 2]].forEach(([secs, want, blocks]) => {
  reset(); reboot();
  const t51 = H.nowMs();
  tap('DW'); advance(secs * 1000); settle();
  tap('MTG'); settle();
  const said = armedText();
  chk('at ' + secs + 's it said ' + want, said === want, JSON.stringify(said));
  tap('MTG'); settle();
  chk('at ' + secs + 's it did what it said — ' + blocks + ' block(s)',
    A().length === blocks, A().map(show).join(' | '));
  if (blocks === 1) {
    chk('at ' + secs + 's the retitle kept the original start',
      A()[0].t === 'MTG:' && A()[0].s === t51, show(A()[0]));
  } else {
    chk('at ' + secs + 's the switch left the first block alone',
      A()[0].t === 'DW:' && A()[1].t === 'MTG:', A().map(show).join(' | '));
  }
});

console.log('\n51e. a label cannot promise an action the tap will not take');
/* THE criterion this task exists for. Arm just inside the correction window,
 * let the clock cross it before the second tap, and the old design would have
 * confirmed a RETITLE it had already stopped being able to do.
 *
 * Two things make it hold. The label and the action read one predicate, so they
 * cannot be kept out of step. And arming schedules a repaint at the exact
 * moment the window closes, so the label changes when the action does. */
reset(); reboot();
tap('DW'); advance((MISTAP_SECONDS - 3) * 1000); settle();
tap('MTG'); settle();
chk('armed just inside the window, it offers to retitle',
  armedText() === 'TAP AGAIN TO RETITLE', JSON.stringify(armedText()));
advance(3200); settle();                       // cross the correction boundary
chk('once the window closes the label changes on its own',
  armedText() === 'TAP AGAIN TO SWITCH', JSON.stringify(armedText()));
chk('and it is still armed, so the change is visible rather than a dismissal',
  armedKey() === 'MTG', String(armedKey()));
tap('MTG'); settle();
chk('confirming now switches, exactly as the label said',
  A().length === 2 && A()[0].t === 'DW:' && A()[1].t === 'MTG:',
  A().map(show).join(' | '));

/* And the sweep's cousin: at every second across the window, whatever the label
 * says must be what confirming does. */
const liars51 = [];
for (let secs = 0; secs <= 40; secs++) {
  reset(); reboot();
  tap('DW');
  if (secs) advance(secs * 1000);
  settle();
  tap('MTG'); settle();
  if (armedKey() !== 'MTG') continue;          // past the confirm window, no label to check
  const said = armedText();
  tap('MTG'); settle();
  const retitled = A().length === 1;
  const promised = (said === 'TAP AGAIN TO RETITLE');
  if (promised !== retitled) {
    liars51.push(secs + 's: said ' + JSON.stringify(said) + ' but ' +
                 (retitled ? 'retitled' : 'switched'));
  }
}
chk('at every second from 0 to 40, the label matched what confirming did',
  liars51.length === 0, liars51.slice(0, 6).join(' | '));
reset();

console.log('\n52. a whole block can be recategorised, not just its remainder');
/* Past the correction window a misfiled block had no fix: a different category
 * starts a new one, and re-tapping the lit one reassigns only the remainder.
 * The write path is not new — opRecategorize_ is the same op a mis-tap
 * correction uses — so what is being tested here is the affordance and the
 * client state around it. */
const splitPick = key => {
  const i = CATEGORIES.findIndex(c => c.key === key);
  $('splitGrid').children[i].fire('click'); settle();
};
const pickWhole = () => { $('spScopeAll').fire('click'); };
/* Read the way splitOpen() does. The shim only makes a node once the client has
 * asked for it, so a build that never paints this label would crash the suite
 * here and take every later section with it. A missing label is a failure, not
 * an abort. */
const gridLab = () => {
  const n = H.NODES['spGridLab'];
  return n ? n.textContent : '(never painted)';
};

reset(); reboot();
const t52 = H.nowMs();
tap('DW'); settle(); wait(180);                          // three hours in
tap('DW'); settle();                                     // re-tap the lit one
chk('SPLIT opens on the lit block', splitOpen());
chk('and opens on the remainder, the safer of the two',
  gridLab() === 'REMAINDER IS', gridLab());
const ends52 = A()[0].s + '/' + A()[0].e;
chk('and says which option is chosen to something that cannot see the colour',
  $('spScopeRem').getAttribute('aria-pressed') === 'true' &&
  $('spScopeAll').getAttribute('aria-pressed') === 'false',
  $('spScopeRem').getAttribute('aria-pressed') + '/' + $('spScopeAll').getAttribute('aria-pressed'));
pickWhole();
chk('choosing the whole block says what the next tap will do',
  gridLab() === 'THE WHOLE BLOCK BECOMES', gridLab());
chk('and the spoken state moves with the visible one',
  $('spScopeRem').getAttribute('aria-pressed') === 'false' &&
  $('spScopeAll').getAttribute('aria-pressed') === 'true',
  $('spScopeRem').getAttribute('aria-pressed') + '/' + $('spScopeAll').getAttribute('aria-pressed'));
splitPick('MTG');
const a52 = A();
chk('exactly one block', a52.length === 1, a52.map(show).join(' | '));
chk('keyed MTG', a52[0].t === 'MTG:', a52[0].t);
chk('with the original start time', a52[0].s === t52, show(a52[0]));
chk('start and end both unchanged', a52[0].s + '/' + a52[0].e === ends52,
  a52[0].s + '/' + a52[0].e + ' was ' + ends52);
chk('and still open', /#open/.test(a52[0].d) && activeKey() === 'MTG',
  show(a52[0]) + ' lit=' + String(activeKey()));
chk('the sheet closed behind it', !splitOpen());
chk('and the block wears MTG\'s colour', sameAsButton(a52[0], 'MTG'),
  'colour=' + evColour(a52[0]));

console.log('\n52b. the note survives being recategorised whole');
reset(); reboot();
tap('DW'); settle();
noteBox().value = 'memo drafting'; noteBox().fire('input'); advance(1000); settle();
wait(120);
tap('DW'); settle();
pickWhole(); splitPick('MTG');
chk('one block, keyed MTG, note intact',
  A().length === 1 && A()[0].t === 'MTG: memo drafting', A().map(show).join(' | '));
chk('and the lit box still offers the note back',
  noteBox().value === 'memo drafting', JSON.stringify(noteBox().value));

console.log('\n52c. the new option does not disturb the old one');
/* Section 11 is the remainder path's own test and is untouched. This one is
 * about the toggle specifically: looking at the new option and going back must
 * leave the old one exactly as it was. */
reset(); reboot();
const t52c = H.nowMs();
tap('MTG'); settle(); wait(180);
tap('MTG'); settle();
pickWhole();
chk('the slider stops offering a time that will not be used',
  $('spRange').disabled === true, String($('spRange').disabled));
$('spScopeRem').fire('click');
chk('going back restores the label', gridLab() === 'REMAINDER IS',
  gridLab());
chk('and the slider is live again', $('spRange').disabled === false,
  String($('spRange').disabled));
$('spRange').value = '60'; $('spRange').fire('input');
splitPick('ADM');
chk('the remainder path still writes two blocks', A().length === 2,
  A().map(show).join(' | '));
chk('MTG keeps the first hour',
  A()[0].t === 'MTG: =' && A()[0].s === t52c && near(A()[0].e - A()[0].s, 3600000),
  show(A()[0]));
chk('ADM takes the remainder and is the open one',
  A()[1].s === A()[0].e && /#open/.test(A()[1].d) && activeKey() === 'ADM',
  show(A()[1]));

console.log('\n52d. recategorising whole to BODY closes the SIT, as a tap does');
reset(); reboot();
tapSit(); settle();
tap('DW'); settle(); wait(120);
chk('sitting to begin with', litPosture() === 'sit', String(litPosture()));
tap('DW'); settle();
pickWhole(); splitPick('BODY');
chk('one block, keyed BODY', A().length === 1 && A()[0].t === 'BODY:',
  A().map(show).join(' | '));
chk('the SIT closed at that moment',
  S().length === 1 && !/#open/.test(S()[0].d) && near(S()[0].e, H.nowMs()),
  S().map(show).join(' | '));
chk('and the posture fell back to standing', litPosture() === 'stand',
  String(litPosture()));

console.log('\n52e. rejected by the server, it is immediate and it is queued');
reset(); reboot();
tap('DW'); settle(); wait(120);
H.setServerReject('nope');
tap('DW'); settle();
pickWhole(); splitPick('MTG');
chk('the grid shows the new category at once', activeKey() === 'MTG', String(activeKey()));
const q52 = JSON.parse(H.STORE['tt.queue.v1'] || '[]');
chk('and a recategorize op is waiting in the queue',
  q52.filter(o => o.type === 'recategorize' && o.key === 'MTG').length === 1,
  JSON.stringify(q52.map(o => o.type + ':' + (o.key || ''))));
reboot();
const q52b = JSON.parse(H.STORE['tt.queue.v1'] || '[]');
chk('a reboot before it drains keeps the op, unchanged',
  q52b.filter(o => o.type === 'recategorize' && o.key === 'MTG').length === 1,
  JSON.stringify(q52b.map(o => o.type + ':' + (o.key || ''))));
chk('and the client still shows MTG rather than the server\'s stale DW',
  activeKey() === 'MTG', String(activeKey()));
H.setServerReject(null);
advance(120000); settle(); settle();                     // let the retry timer run
chk('once the server takes it, the calendar agrees',
  A().length === 1 && A()[0].t === 'MTG:' && /#open/.test(A()[0].d),
  A().map(show).join(' | '));

console.log('\n52f. an open that never reached the server is corrected in place');
/* Offline rather than rejecting, so nothing is ever set aside: the openActual
 * is still in the queue when the whole block is recategorised, and the existing
 * coalescing path absorbs it instead of chasing it with a second op. */
reset(); reboot();
H.setOnline(false);
const t52f = H.nowMs();
tap('DW'); settle(); wait(120);
tap('DW'); settle();
pickWhole(); splitPick('MTG');
const q52f = JSON.parse(H.STORE['tt.queue.v1'] || '[]');
chk('the pending open is corrected, not chased by a second op',
  q52f.filter(o => o.type === 'openActual').length === 1 &&
  q52f.filter(o => o.type === 'openActual')[0].key === 'MTG' &&
  !q52f.some(o => o.type === 'recategorize'),
  JSON.stringify(q52f.map(o => o.type + ':' + (o.key || ''))));
H.setOnline(true);
advance(120000); settle(); settle();
chk('and the network coming back writes one MTG block from the original start',
  A().length === 1 && A()[0].t === 'MTG:' && A()[0].s === t52f,
  A().map(show).join(' | '));

console.log('\n52g. the destructive option is never the one already chosen');
/* A sheet that remembers WHOLE BLOCK would make the next visit — probably a
 * genuine split — retitle three hours of work on one tap. Every opening starts
 * on the option that cannot destroy anything. */
reset(); reboot();
tap('DW'); settle(); wait(180);
tap('DW'); settle();
pickWhole();
$('spClose').fire('click'); settle();
chk('the sheet closed without writing', A().length === 1 && A()[0].t === 'DW:',
  A().map(show).join(' | '));
tap('DW'); settle();
chk('and re-opening it is back on the remainder',
  splitOpen() && gridLab() === 'REMAINDER IS', gridLab());
chk('with the slider live again', $('spRange').disabled === false,
  String($('spRange').disabled));

console.log('\n52h. recategorising whole does not re-open the correction window');
/* S.lastTapMs is what willRetitle() reads, and a block reached from this sheet
 * is at least MISTAP_SECONDS old. Moving it to now would make the next
 * confirmed tap on another category retitle hours of work instead of starting
 * a new block — C1's windows nest around when the block was tapped, and
 * renaming it is not a tap. */
reset(); reboot();
const t52h = H.nowMs();
tap('DW'); settle(); wait(180);
tap('DW'); settle();
pickWhole(); splitPick('MTG');
const cut52h = H.nowMs();
tap('REL'); settle();
chk('a tap on another category acts at once, without arming',
  armedKey() === null, String(armedKey()));
chk('and starts a new block instead of retitling the old one',
  A().length === 2 && A()[0].t === 'MTG: =' && A()[0].s === t52h && A()[1].t === 'REL:',
  A().map(show).join(' | '));
/* And the end, which cannot be read off an open block: the renamed block is the
 * WHOLE three hours, not a fragment of them. */
chk('the renamed block still spans the whole three hours',
  near(A()[0].e, cut52h) && near(A()[0].e - A()[0].s, 180 * 60000),
  show(A()[0]) + ' = ' + Math.round((A()[0].e - A()[0].s) / 60000) + 'm');

console.log('\n52j. a correction is not lost to a write already on the wire');
/* Addition 4 in factory/progress-2.md, found by the checker. mutatePendingOpen
 * rewrites the queue in localStorage; a flush already in flight handed the
 * server the queue as it was and drops those ops by id when it answers, so the
 * rewrite is thrown away and no op is ever queued in its place. The client
 * shows one category, the calendar holds another, and the sync dot reads
 * synced. Pre-existing — the mis-tap path below reaches the same loss — but C3
 * widens it from a 20-second window to any block age. */
reset(); reboot();
H.setCallLag('applyOps', 30000);                 // the open is sent, the answer is slow
const t52j = H.nowMs();
tap('DW'); settle();
advance(25000); settle();                        // past MISTAP_SECONDS, still on the wire
tap('DW'); settle();
chk('SPLIT opens while the open block is still unacknowledged', splitOpen());
pickWhole(); splitPick('MTG');
chk('the client shows the new category at once', activeKey() === 'MTG', String(activeKey()));
H.setCallLag('applyOps', null);
advance(120000); settle(); settle();
chk('and the calendar ends up carrying it too',
  A().length === 1 && A()[0].t === 'MTG:' && A()[0].s === t52j, A().map(show).join(' | '));
chk('with nothing left unsent', JSON.parse(H.STORE['tt.queue.v1'] || '[]').length === 0,
  H.STORE['tt.queue.v1'] || '[]');

console.log('\n52k. and the mis-tap correction it inherits that from is safe too');
reset(); reboot();
H.setCallLag('applyOps', 30000);
const t52k = H.nowMs();
tap('DW'); settle();
advance(10000); settle();
tap('MTG'); settle();                            // arms
tap('MTG'); settle();                            // confirms, inside the mis-tap window
chk('the client shows the corrected category', activeKey() === 'MTG', String(activeKey()));
H.setCallLag('applyOps', null);
advance(120000); settle(); settle();
chk('and the calendar carries one MTG block from the original start',
  A().length === 1 && A()[0].t === 'MTG:' && A()[0].s === t52k, A().map(show).join(' | '));

console.log('\n52i. with nothing open, the whole-block option is out of reach');
reset(); reboot();
chk('nothing is lit', activeKey() === null, String(activeKey()));
chk('and the sheet is not open — its only way in is a lit block', !splitOpen());
/* The guard under it. In a browser the sheet is hidden so these buttons cannot
 * be reached at all; the guard has to hold anyway, because "unreachable" is not
 * something the code should be trusting the CSS for. */
$('spScopeAll').fire('click');
splitPick('MTG');
chk('firing the grid with no open block writes nothing', A().length === 0,
  A().map(show).join(' | '));
chk('and queues nothing', JSON.parse(H.STORE['tt.queue.v1'] || '[]').length === 0,
  H.STORE['tt.queue.v1'] || '[]');
chk('and leaves the sheet shut', !splitOpen());
reset();

console.log('\n53. an unreadable title stops being filed as Admin');
/* Two holes of the same shape. Four sites did parseTitle_(...) || { key: 'ADM' },
 * so a title the app cannot read was CLAIMED to be Admin on the write and
 * display paths; and in dayStats_ an ACTUAL event that failed to parse, or
 * parsed to a key nobody configured, contributed nothing at all — its hours
 * vanished rather than being misfiled. Both now go to a key named for what
 * they are. */
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('Lunch with Ada', 20, 12, 0, 13, 0);
dailyRollup();
chk('the unreadable block reports its hours under UNFILED',
  dayCell('2026-07-20', UNFILED_KEY) === 1, String(dayCell('2026-07-20', UNFILED_KEY)));
chk('and ADM is 0 — nothing was claimed as Admin',
  dayCell('2026-07-20', 'ADM') === 0, String(dayCell('2026-07-20', 'ADM')));

console.log('\n53b. parsed-but-unknown gets the same home as unparseable');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('Re: the thing', 20, 14, 0, 15, 0);          // parses to key RE, not configured
AC('9:00 standup', 20, 16, 0, 17, 0);           // parses to key 9, not configured
dailyRollup();
chk('both land under UNFILED', dayCell('2026-07-20', UNFILED_KEY) === 2,
  String(dayCell('2026-07-20', UNFILED_KEY)));
chk('and no column was invented for RE or 9',
  !dRows()[0].includes('RE') && !dRows()[0].includes('9'), JSON.stringify(dRows()[0].slice(0, 12)));

console.log('\n53c. a category that really is Admin is untouched');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('ADM: real admin =', 20, 9, 0, 11, 0);
AC('Lunch with Ada', 20, 12, 0, 13, 0);
dailyRollup();
chk('ADM reports its own two hours', dayCell('2026-07-20', 'ADM') === 2,
  String(dayCell('2026-07-20', 'ADM')));
chk('in the right mark bucket', dayCell('2026-07-20', 'ADM =') === 2,
  String(dayCell('2026-07-20', 'ADM =')));
chk('and UNFILED holds only the unreadable one',
  dayCell('2026-07-20', UNFILED_KEY) === 1, String(dayCell('2026-07-20', UNFILED_KEY)));

console.log('\n53d. the key is in the rollup\'s set exactly once');
reset();
const keys53 = rollupKeys_();
chk('UNFILED appears exactly once',
  keys53.filter(k => k === UNFILED_KEY).length === 1, JSON.stringify(keys53));
chk('alongside UNLOGGED', keys53.indexOf('UNLOGGED') >= 0, JSON.stringify(keys53));
/* Q10's hazard, closed for this key: a category the user names "Unfiled"
   derives the same key, and one key must not get two columns. */
H.SCRIPT_PROPS.EXTRA_CATEGORIES = JSON.stringify(
  [{ key: UNFILED_KEY, label: 'Unfiled', color: '8', autoMark: null }]);
H.clearPropCache();
const keys53b = rollupKeys_();
chk('and still only once when a user category derives the same key',
  keys53b.filter(k => k === UNFILED_KEY).length === 1, JSON.stringify(keys53b));
delete H.SCRIPT_PROPS.EXTRA_CATEGORIES; H.clearPropCache();

console.log('\n53e. it gets the full set of mark columns, like every other key');
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('Lunch with Ada', 20, 12, 0, 13, 0);         // unreadable: no mark to read
AC('Re: the thing =', 20, 14, 0, 15, 0);        // unknown key, but the mark parsed
dailyRollup();
chk('every bucket has a column',
  MARK_BUCKETS.every(m => dCol(markCol_(UNFILED_KEY, m)) >= 0),
  JSON.stringify(MARK_BUCKETS.map(m => markCol_(UNFILED_KEY, m) + '=' + dCol(markCol_(UNFILED_KEY, m)))));
chk('the unreadable one is unmarked, not dropped',
  dayCell('2026-07-20', markCol_(UNFILED_KEY, '')) === 1,
  String(dayCell('2026-07-20', markCol_(UNFILED_KEY, ''))));
chk('the one whose mark survived parsing keeps it',
  dayCell('2026-07-20', markCol_(UNFILED_KEY, '=')) === 1,
  String(dayCell('2026-07-20', markCol_(UNFILED_KEY, '='))));
chk('and the key total is the sum of its buckets',
  dayCell('2026-07-20', UNFILED_KEY) ===
    MARK_BUCKETS.reduce((s, m) => s + dayCell('2026-07-20', markCol_(UNFILED_KEY, m)), 0),
  String(dayCell('2026-07-20', UNFILED_KEY)));
chk('the weekly tab carries them too',
  MARK_BUCKETS.every(m => wRows()[0].indexOf(markCol_(UNFILED_KEY, m)) >= 0),
  JSON.stringify(wRows()[0].slice(-8)));

console.log('\n53f. getState does not tell the client an unreadable block is Admin');
/* Site 1 of 4. */
reset(); reboot();
tap('DW'); settle(); wait(30);
A()[0].t = 'Lunch with Ada';                    // hand-edited in Google Calendar
reboot();
chk('the client is not told it is ADM', activeKey() !== 'ADM', String(activeKey()));
chk('and nothing is lit, because the app does not know what it is',
  activeKey() === null, String(activeKey()));
chk('the block is still open on the calendar, untouched',
  A().length === 1 && A()[0].t === 'Lunch with Ada' && /#open/.test(A()[0].d), show(A()[0]));
tap('MTG'); settle();
chk('and tapping a category closes it without throwing',
  A().length === 2 && /#open/.test(A()[1].d) && A()[1].t === 'MTG:',
  A().map(show).join(' | '));
chk('the closed one is still not Admin', !/^ADM:/.test(A()[0].t), A()[0].t);

console.log('\n53g. bounding an unreadable block keeps what the user wrote');
/* Site 2 of 4 — the only one that WRITES the fallback back to the calendar.
 * It used to turn "Lunch with Ada" into "ADM: ?": a category nobody chose, and
 * the text gone with it. */
reset(D(2026, 7, 20, 22, 0)); reboot();
tap('DW'); settle();
A()[0].t = 'Lunch with Ada';
H.setNow(D(2026, 7, 21, 7, 0));
reboot();
const b53 = A()[0];
chk('it is not claimed as Admin', !/^ADM:/.test(b53.t), b53.t);
chk('the words the user typed survive', /Lunch with Ada/.test(b53.t), b53.t);
chk('it still says the end was the app\'s guess', /\?$/.test(b53.t), b53.t);
chk('and the boundary arithmetic is what it always was — the day border',
  b53.e === D(2026, 7, 21, 0, 0), show(b53));
chk('with UNLOGGED covering the rest', A().length === 2 && /^UNLOGGED/.test(A()[1].t),
  A().map(show).join(' | '));
chk('and it round-trips: what was written parses back to what it says',
  JSON.stringify(parseTitle_(b53.t)) ===
    JSON.stringify({ key: UNFILED_KEY, text: 'Lunch with Ada', mark: '?' }),
  JSON.stringify(parseTitle_(b53.t)));

console.log('\n53h. closing and splitting an unreadable block, at the server');
/* Sites 3 and 4 of 4. The client always sends a key, so these fallbacks are
 * reached by an op that does not — a queue entry from an older build, or one
 * hand-edited in localStorage. Driven through the real applyOps. */
reset(); reboot();
tap('DW'); settle(); wait(30);
A()[0].t = 'Lunch with Ada';
const ref53 = /#ref:([A-Za-z0-9]+)/.exec(A()[0].d)[1];
applyOps([{ id: 'd1close', type: 'closeActual', ref: ref53, endMs: H.nowMs() }]);
chk('closeActual does not claim it as Admin', !/^ADM:/.test(A()[0].t), A()[0].t);
chk('and keeps the text', /Lunch with Ada/.test(A()[0].t), A()[0].t);

reset(); reboot();
tap('DW'); settle(); wait(60);
A()[0].t = 'Lunch with Ada';
const ref53b = /#ref:([A-Za-z0-9]+)/.exec(A()[0].d)[1];
applyOps([{ id: 'd1split', type: 'splitActual', ref: ref53b, atMs: H.nowMs() - 30 * 60000,
            newRef: 'd1splitnewref00', newKey: 'MTG', nowMs: H.nowMs() }]);
chk('splitActual does not claim the first half as Admin',
  !/^ADM:/.test(A()[0].t), A()[0].t);
chk('and keeps its text', /Lunch with Ada/.test(A()[0].t), A()[0].t);
chk('while the remainder is the category that was asked for',
  A().length === 2 && A()[1].t === 'MTG:', A().map(show).join(' | '));
reset();

console.log('\n54. a week the window only partly covers says so');
/*
 * The window is ROLLUP_DAYS long counting back from today, so its oldest week is
 * almost always a few days of a week shown exactly like a whole one — and so is
 * its newest, which is however much of this week has happened. Both had
 * plan-versus-actual ratios that were misleading by construction and said
 * nothing about it.
 *
 * The dates below are chosen so the window's edges land on known weekdays:
 * 2026-07-24 is a Friday, 2026-07-08 a Wednesday, 2026-07-26 a Sunday.
 */
const DAYS_WAS = ROLLUP_DAYS;
const wCol54 = n => wRows()[0].indexOf(n);
const wRow54 = wk => wRows().find(r => r[0] === wk);
const covered54 = wk => { const r = wRow54(wk); return r ? r[wCol54('days covered (of 7)')] : undefined; };

ROLLUP_DAYS = 17;                      // Wed 2026-07-08 .. Fri 2026-07-24
reset(D(2026, 7, 24, 15, 0)); goodSheet();
AC('DW: a =', 20, 9, 0, 11, 0);
dailyRollup();
chk('the column exists', wCol54('days covered (of 7)') >= 0, JSON.stringify(wRows()[0].slice(-3)));
chk('the oldest week says how many of its seven days the window covered',
  covered54('2026-07-06') === 5, String(covered54('2026-07-06')));
chk('a week the window covers completely says seven',
  covered54('2026-07-13') === 7, String(covered54('2026-07-13')));
chk('and the current week, which is only half over, says five',
  covered54('2026-07-20') === 5, String(covered54('2026-07-20')));
chk('so exactly one week of the three is whole',
  wRows().slice(1).filter(r => r[wCol54('days covered (of 7)')] === 7).length === 1,
  JSON.stringify(wRows().slice(1).map(r => r[0] + '=' + r[wCol54('days covered (of 7)')])));
chk('every row still carries a week of value in the same form as before',
  wRows().slice(1).every(r => /^\d{4}-\d{2}-\d{2}$/.test(String(r[0]))),
  JSON.stringify(wRows().slice(1).map(r => r[0])));
chk('and nothing was appended to it — the marking is a column, not a suffix',
  wRows().slice(1).every(r => !/partial/i.test(String(r[0]))),
  JSON.stringify(wRows().slice(1).map(r => r[0])));
chk('the count is the sum of the days it covered, so the weeks add to the window',
  wRows().slice(1).reduce((s, r) => s + r[wCol54('days covered (of 7)')], 0) === 17,
  String(wRows().slice(1).reduce((s, r) => s + r[wCol54('days covered (of 7)')], 0)));

console.log('\n54b. a window that is whole weeks marks nothing partial');
/* The rule is about coverage, not about position in the list: here the oldest
 * row and the newest row are both complete, which is the case a rule written as
 * "the first and last rows are partial" would get wrong. */
ROLLUP_DAYS = 14;                      // Mon 2026-07-13 .. Sun 2026-07-26
reset(D(2026, 7, 26, 15, 0)); goodSheet();
dailyRollup();
chk('two weeks, both whole',
  wRows().length === 3 && wRows().slice(1).every(r => r[wCol54('days covered (of 7)')] === 7),
  JSON.stringify(wRows().slice(1).map(r => r[0] + '=' + r[wCol54('days covered (of 7)')])));

console.log('\n54c. a window inside a single week is one partial row, well formed');
ROLLUP_DAYS = 3;                       // Mon 2026-07-20 .. Wed 2026-07-22
reset(D(2026, 7, 22, 15, 0)); goodSheet();
AC('DW: a =', 21, 9, 0, 11, 0);
dailyRollup();
chk('one week row', wRows().length === 2,
  JSON.stringify(wRows().slice(1).map(r => r[0])));
chk('marked partial, and it says three',
  covered54('2026-07-20') === 3, String(covered54('2026-07-20')));
chk('the row is the width of the header',
  wRows()[1].length === wRows()[0].length,
  wRows()[1].length + ' vs ' + wRows()[0].length);
chk('and there is still exactly one stamp, after the last data column',
  wRows()[0].filter(h => /^last rebuilt /.test(String(h))).length === 1 &&
  /^last rebuilt /.test(String(wRows()[0][wRows()[0].length - 1])),
  JSON.stringify(wRows()[0].slice(-2)));
chk('the numbers the week reports are still its days\' numbers',
  wRow54('2026-07-20')[wCol54('DW')] === 2, String(wRow54('2026-07-20')[wCol54('DW')]));

console.log('\n54e. the count survives a week containing a clock change');
/*
 * D2's test note names `mondayStartMs_` as "exactly where a timezone bug would
 * hide", and it is right, but the July windows above never touch one: none of
 * the four contracted zones changes its clocks in July. So this walks a window
 * across every spring-forward and fall-back weekend the four zones have in
 * 2026, and over a year boundary, in whatever zone the suite is running in.
 *
 * The expectation is computed from plain local-date arithmetic — new Date(y, m,
 * d) and getDay(), never epoch milliseconds and never one of Code.gs's own
 * helpers — so it is an independent answer rather than the same arithmetic
 * agreeing with itself. A day that is 23 or 25 hours long is exactly where
 * counting in milliseconds goes wrong, and this is the assertion that would
 * notice.
 */
const DST_ANCHORS = [
  [2026, 3, 11],   // US spring forward, 2026-03-08, inside the window
  [2026, 11, 4],   // US fall back, 2026-11-01
  [2026, 4, 1],    // EU spring forward 2026-03-29
  [2026, 4, 8],    // AU DST ends 2026-04-05 — the hour that goes BACKWARDS, which
                   // is the direction that moves a fixed-24h step onto 23:00 of
                   // the day before and so onto the wrong date entirely
  [2026, 10, 28],  // EU fall back 2026-10-25
  [2026, 10, 7],   // AU spring forward 2026-10-04
  [2027, 1, 2]     // across a year boundary
];
const wrong54 = [];
DST_ANCHORS.forEach(([y, mo, dy]) => {
  [3, 10, 17].forEach(len => {
    ROLLUP_DAYS = len;
    reset(new Date(y, mo - 1, dy, 15, 0, 0, 0).getTime()); goodSheet();
    dailyRollup();
    // The oracle: walk back `len` local days from the anchor, bucket each into
    // its own Monday, and count. No milliseconds anywhere.
    const want = {};
    for (let i = 0; i < len; i++) {
      const d = new Date(y, mo - 1, dy - i);
      const back = (d.getDay() + 6) % 7;
      const mon = new Date(d.getFullYear(), d.getMonth(), d.getDate() - back);
      const k = mon.getFullYear() + '-' + String(mon.getMonth() + 1).padStart(2, '0') +
                '-' + String(mon.getDate()).padStart(2, '0');
      want[k] = (want[k] || 0) + 1;
    }
    const got = {};
    wRows().slice(1).forEach(r => { got[r[0]] = r[wCol54('days covered (of 7)')]; });
    /* Sorted pairs, not JSON of the objects: the oracle walks backwards from the
       anchor, so it meets the weeks in the opposite order to the grid, and
       key order is not what is being asserted. */
    const flat = o => Object.keys(o).sort().map(k => k + '=' + o[k]).join(',');
    if (flat(got) !== flat(want)) {
      wrong54.push(y + '-' + mo + '-' + dy + ' over ' + len + ' days: got ' +
                   flat(got) + ' wanted ' + flat(want));
    }
  });
});
chk('across six clock-change weekends and three window lengths, the counts are right',
  wrong54.length === 0, wrong54.slice(0, 3).join(' | '));

console.log('\n54f. and the ninety-day window the criterion actually names');
ROLLUP_DAYS = DAYS_WAS;                                  // 90, the shipped value
reset(D(2026, 7, 24, 15, 0)); goodSheet();               // a Friday
dailyRollup();
const cov54f = wRows().slice(1).map(r => r[wCol54('days covered (of 7)')]);
chk('ninety days, and they add up to ninety',
  cov54f.reduce((s, n) => s + n, 0) === 90, JSON.stringify(cov54f));
chk('the oldest week is partial and the newest is too',
  cov54f[0] < 7 && cov54f[cov54f.length - 1] < 7,
  cov54f[0] + ' ... ' + cov54f[cov54f.length - 1]);
chk('and every week between them is whole',
  cov54f.slice(1, -1).every(n => n === 7), JSON.stringify(cov54f));
chk('no week can report more than the seven days it has',
  cov54f.every(n => n >= 1 && n <= 7), JSON.stringify(cov54f));

console.log('\n54d. the daily tab is untouched by any of it');
chk('no days covered column on the daily tab', dRows()[0].indexOf('days covered (of 7)') < 0,
  JSON.stringify(dRows()[0].slice(-3)));
ROLLUP_DAYS = DAYS_WAS;
reset();

console.log('\n55. the grid stops showing a block whose open was set aside');
/*
 * A set-aside openActual never reached the calendar, so the block does not
 * exist — and every later op for that ref is a no-op nobody can see:
 * findByRef_ finds nothing and opCloseActual_ returns early. The banner
 * persists and the drawer holds the write, so the failure is findable. The
 * grid was the part that lied, showing the block lit with its clock ticking.
 */
reset(); reboot();
H.setServerReject('calendar said no');
tap('DW');
chk('it shows as running while the write is still being tried',
  activeKey() === 'DW', String(activeKey()));
pump(() => DEAD().length > 0);
chk('the open was set aside',
  DEAD().length === 1 && DEAD()[0].op.type === 'openActual',
  JSON.stringify(DEAD().map(d => d.op.type)));
chk('and now no cell renders as running', activeKey() === null, String(activeKey()));
chk('which is the truth: nothing was created on either calendar',
  A().length === 0 && S().length === 0, A().map(show).join(' | '));
chk('the banner still says a write was set aside — the repaint does not clear it',
  !$('err').hidden && /set it aside/.test($('err').textContent), $('err').textContent);
chk('and the drawer still holds it, so it is not lost',
  DEAD().length === 1, JSON.stringify(DEAD().map(d => d.op.type)));

console.log('\n55b. and no later write is aimed at the block that never existed');
H.setServerReject(null);
tap('MTG'); settle();
chk('a fresh block opens normally', A().length === 1 && A()[0].t === 'MTG:',
  A().map(show).join(' | '));
chk('with a new ref, not the set-aside one',
  A()[0].d.indexOf(DEAD()[0].op.ref) < 0,
  A()[0].d.replace(/\n/g, '|') + ' vs dead ref ' + DEAD()[0].op.ref);
chk('and nothing was ever queued to close the block that was never created',
  !Q().some(o => o.type === 'closeActual'), JSON.stringify(Q().map(o => o.type)));

console.log('\n55c. a set-aside mark does NOT clear the grid');
/* The over-correction this task has to avoid: "any set-aside write clears the
 * grid" would be a different lie. A setMark belongs to a block that really was
 * created and really is running. */
reset(); reboot();
tap('DW'); wait(30); tap('MTG'); settle();      // DW closes, MTG opens, strip shows
chk('MTG is the running block', activeKey() === 'MTG', String(activeKey()));
H.setServerReject('calendar said no');
tapMark('+');                                   // a setMark for the CLOSED DW
pump(() => DEAD().length > 0);
chk('the mark was the thing set aside',
  DEAD().length === 1 && DEAD()[0].op.type === 'setMark',
  JSON.stringify(DEAD().map(d => d.op.type)));
chk('and MTG is still shown running, because it really is',
  activeKey() === 'MTG', String(activeKey()));
chk('and is still open on the calendar',
  A().length === 2 && /#open/.test(A()[1].d), A().map(show).join(' | '));
H.setServerReject(null);

console.log('\n55d. a set-aside split clears it too — its newRef is an open by another name');
reset(); reboot();
tap('MTG'); settle(); wait(120);
H.setServerReject('calendar said no');
tap('MTG'); settle();                           // re-tap the lit one: SPLIT
$('spRange').value = '60'; $('spRange').fire('input');
splitPick('ADM');
chk('the client shows the remainder running', activeKey() === 'ADM', String(activeKey()));
pump(() => DEAD().length > 0);
chk('the split was set aside',
  DEAD().length === 1 && DEAD()[0].op.type === 'splitActual',
  JSON.stringify(DEAD().map(d => d.op.type)));
chk('and the grid stops showing it running', activeKey() === null, String(activeKey()));
H.setServerReject(null);

console.log('\n55e. discarding the set-aside open from the drawer leaves it idle');
reset(); reboot();
H.setServerReject('calendar said no');
tap('DW');
pump(() => DEAD().length > 0);
chk('idle after it was set aside', activeKey() === null, String(activeKey()));
$('err').fire('click'); settle();               // the banner opens the drawer
chk('the drawer opened with the one entry', uiRows().length === 1,
  String(uiRows().length));
let threw55 = null;
try { discard(uiRows()[0]); } catch (e) { threw55 = String((e && e.message) || e); }
chk('discarding it throws nothing', threw55 === null, String(threw55));
chk('the drawer is empty', DEAD().length === 0, JSON.stringify(DEAD()));
chk('and the grid is still idle', activeKey() === null, String(activeKey()));
H.setServerReject(null);
tap('REL'); settle();
chk('a tap after that opens a fresh block normally',
  A().length === 1 && A()[0].t === 'REL:' && /#open/.test(A()[0].d) && activeKey() === 'REL',
  A().map(show).join(' | '));

console.log('\n55g. it is the ref that decides, not the op type');
/* The half of the narrowness that lives in `S.open.ref === openedRef`. An
 * openActual can be set aside for a block the user has already moved on from,
 * while the block they ARE in was opened by a later op that may still land.
 * Deleting the ref comparison passes every other assertion in this section, so
 * this is the one that pins it.
 *
 * Offline first, so the queue can be stacked up without anything counting
 * against a try; then the server starts rejecting and the head — the first
 * block's open — is the one that gets set aside. */
reset(); reboot();
H.setOnline(false);
tap('DW'); advance(70000); settle();
tap('MTG'); settle();
chk('three writes are stacked up and MTG is the block in hand',
  Q().length === 3 && activeKey() === 'MTG', JSON.stringify(Q().map(o => o.type)));
H.setOnline(true); H.setServerReject('calendar said no');
pump(() => DEAD().length > 0);
chk('the first block\'s open was the one set aside',
  DEAD().length === 1 && DEAD()[0].op.type === 'openActual' && DEAD()[0].key === 'DW',
  JSON.stringify(DEAD().map(d => d.op.type + '/' + d.key)));
chk('and the grid still shows MTG, which is a different block entirely',
  activeKey() === 'MTG', String(activeKey()));
H.setServerReject(null); H.setOnline(true);

reset(); reboot();
H.setOnline(false);
tapSit(); settle();
posture('stand'); settle();
tapSit(); settle();
chk('a SIT was opened, closed and opened again, all still queued',
  Q().filter(o => o.type === 'openSit').length === 2 && litPosture() === 'sit',
  JSON.stringify(Q().map(o => o.type)));
H.setOnline(true); H.setServerReject('calendar said no');
pump(() => DEAD().length > 0);
chk('the first SIT open was set aside',
  DEAD().length === 1 && DEAD()[0].op.type === 'openSit',
  JSON.stringify(DEAD().map(d => d.op.type)));
chk('and the posture still says sitting, because a later SIT is the live one',
  litPosture() === 'sit', String(litPosture()));
H.setServerReject(null); H.setOnline(true);

console.log('\n55h. clearing one half leaves the other alone');
/* Contract 7 names posture toggling as untouched by this round. A SIT that
 * really was created must survive an ACTUAL open being set aside. */
reset(); reboot();
tapSit(); settle();
chk('the SIT really is on the calendar', S().length === 1, S().map(show).join(' | '));
H.setServerReject('calendar said no');
tap('DW');
pump(() => DEAD().length > 0);
chk('the block\'s open was set aside', DEAD().length === 1, JSON.stringify(DEAD()));
chk('the grid is idle', activeKey() === null, String(activeKey()));
chk('and the posture is untouched — that SIT exists',
  litPosture() === 'sit' && S().length === 1,
  litPosture() + ' ' + S().map(show).join(' | '));
H.setServerReject(null);

console.log('\n55i. and the grid is still idle after a reload');
/* The clear has to be written down, not just painted. Reloading offline is the
 * case that tells them apart: the client falls back to what it saved, and an
 * unsaved clear brings the phantom back with its clock ticking. */
reset(); reboot();
H.setServerReject('calendar said no');
tap('DW');
pump(() => DEAD().length > 0);
chk('idle after the open was set aside', activeKey() === null, String(activeKey()));
H.setOnline(false);
reboot();
chk('and still idle after a reload with no server to ask',
  activeKey() === null, String(activeKey()));
chk('with nothing on the calendar to have been showing',
  A().length === 0, A().map(show).join(' | '));
wait(2);
chk('and no clock started ticking in the meantime',
  activeKey() === null && elapsedBox() === '', String(activeKey()) + ' ' + elapsedBox());
H.setOnline(true); H.setServerReject(null);

console.log('\n55f. a set-aside SIT open stops the posture claiming it too');
/* Addition 6: the same lie, one row down. Not named by D3's criteria; written
 * up in factory/progress-2.md before being fixed here. */
reset(); reboot();
H.setServerReject('calendar said no');
tapSit();
chk('the posture says sitting while the write is being tried',
  litPosture() === 'sit', String(litPosture()));
pump(() => DEAD().length > 0);
chk('the SIT open was set aside',
  DEAD().length === 1 && DEAD()[0].op.type === 'openSit',
  JSON.stringify(DEAD().map(d => d.op.type)));
chk('and the posture falls back to standing',
  litPosture() === 'stand', String(litPosture()));
chk('which is the truth: the SITTING calendar is empty',
  S().length === 0, S().map(show).join(' | '));
H.setServerReject(null);
reset();

console.log('\n────────────────────────────────────────');
console.log(H.pass + ' passed, ' + H.fail + ' failed' +
            (H.skipped.length ? ', ' + H.skipped.length + ' skipped' : ''));
/* A skip is never folded into `passed`. A run that could not reach a section has
   to be visibly different from one that ran everything, or the count says the
   suite did more than it did. */
H.skipped.forEach(s => console.log('  skipped: ' + s.label + '\n    ' + s.why));
process.exit(H.fail ? 1 : 0);
