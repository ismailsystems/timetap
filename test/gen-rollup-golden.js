/* One-shot: rebuild rollup-golden.json for the current CATEGORIES vocabulary. */
const fs = require('fs');
const path = require('path');
const H = require('./harness.js');
const { reset, reboot, tap, wait } = H;

const D = (y, m, d, hh, mm) => new Date(y, m - 1, d, hh, mm, 0, 0).getTime();
const goodSheet = () => { H.SCRIPT_PROPS.SHEET_ID = 'book'; H.clearPropCache(); };
const tabRows = name => H.SHEETS.book.getSheetByName(name).rows;

function strip(rows) {
  const keys = rollupKeys_();
  const drop = new Set();
  keys.forEach(k => MARK_BUCKETS.forEach(m => drop.add(markCol_(k, m))));
  drop.add('days covered (of 7)');
  const keep = rows[0]
    .map((h, i) => ({ h, i }))
    .filter(x => !drop.has(x.h) && !/^last rebuilt /.test(x.h));
  return rows.map(r => keep.map(x => r[x.i]));
}

reset(D(2026, 7, 20, 9, 0));
reboot();
goodSheet();
tap('DW'); wait(40);
tap('MTG'); wait(50);
tap('ADM'); wait(30);
tap('DW'); wait(20);
tap('FRAG');
const res = dailyRollup();
const tz = Session.getScriptTimeZone();
const outPath = path.join(__dirname, 'fixtures/rollup-golden.json');
let doc = { _note: 'Grids produced after labels replaced keys. Stamp and mark columns are stripped.', _generatedFrom: 'label-vocab', byZone: {} };
if (fs.existsSync(outPath)) {
  try { doc = JSON.parse(fs.readFileSync(outPath, 'utf8')); } catch (e) { /* replace */ }
  doc._note = 'Grids produced after labels replaced keys. Stamp and mark columns are stripped.';
  doc._generatedFrom = 'label-vocab';
  doc.byZone = doc.byZone || {};
}
doc.byZone[tz] = {
  tz,
  days: res.days,
  categories: res.categories,
  grids: {
    daily: strip(tabRows('daily')),
    weekly: strip(tabRows('weekly'))
  }
};
fs.writeFileSync(outPath, JSON.stringify(doc, null, 1) + '\n');
console.log('wrote', tz, 'categories', res.categories, 'daily width', doc.byZone[tz].grids.daily[0].length);
