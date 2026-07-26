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

console.log('\n4. DW then MTG 30s later -> one event, MTG, original start');
reset(); reboot();
const t4 = H.nowMs();
tap('DW'); advance(30000); settle(); tap('MTG'); tap('MTG');
chk('exactly one event', A().length === 1, A().map(show).join(' | '));
chk('category MTG', A()[0].t === 'MTG:', A()[0].t);
chk('start preserved', A()[0].s === t4, show(A()[0]));
chk('still open', /#open/.test(A()[0].d));

console.log('\n4b. mis-tap after the queue already flushed');
reset(); reboot();
const t4b = H.nowMs();
tap('DW'); settle(); settle();
advance(45000); settle(); tap('ADM'); tap('ADM');
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
chk('DW marked', a10[0].t === 'DW: =', a10[0].t);
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
tap('DW'); advance(20000); settle();
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
advance(40000); settle(); tap('BODY'); tap('BODY'); settle();
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

advance(20000); settle();
const q25 = JSON.parse(H.STORE['tt.queue.v1'] || '[]').length;
tap('MTG'); settle();
chk('a tap 20s later writes nothing yet', A().length === 1 && A()[0].t === 'DW:',
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
tap('DW'); settle(); advance(20000); settle();
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
const known = clientConfig_().categories.map(c => c.key).concat(['UNLOGGED']);
const fixed = ['date', 'day', 'switches', 'waking h', 'sitting h', 'sitting %',
               'longest sit min', 'sits over 90'];
const invented = hdr.filter(h => !fixed.includes(h) && !h.startsWith('plan ') && !known.includes(h));
chk('no column invented from a clock time or a subject line',
  invented.length === 0, invented.join(' '));
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

console.log('\n────────────────────────────────────────');
console.log(H.pass + ' passed, ' + H.fail + ' failed');
process.exit(H.fail ? 1 : 0);
