# Review: timetap round 2 — the honest record round — 2026-07-28

Round 1's reviews are `factory/REVIEW.md` and `factory/REVIEW-2.md` and are
read-only. This is the third review document in the project and the first of
round 2.

**How it was run.** Three independent reviewers, none of which saw the build's
reasoning: each was given `factory/HANDOFF-2.md` (the contract),
`factory/progress-2.md` (the builder's claims, to be treated as unproven), and
the diff `a256bdf..HEAD` — and was explicitly denied `factory/log-2.md`, which
is the builder's own account. One ran on a different model. Their lenses were
contract compliance, tampering and landmines, and "how could this pass every
test and still fail the person using it". Every finding below carries the
reproduction that produced it, and the two most severe were re-run by hand
before being written down.

---

## Verdict

**FIX FIRST.**

The build is substantially real and unusually honest about itself. 28 of the 31
contract assertions were independently re-derived and hold. Every contract
violation a reviewer found, the builder had already found and written down —
none was concealed behind a weakened test. The guardrails hold exactly:
`appsscript.json` is byte-identical, no secrets, no new dependency, no
unfinished code hiding behind a passing test, and all eleven read-only files are
untouched. Fourteen deliberately planted faults were caught by the suite.

It does not ship yet, for three reasons.

**The numbers got less true on the exact day the round exists for.** A day the
user logged six hours of work on, and then forgot to press STOP, now reports one
waking hour and a sitting percentage of 500. That is not a debatable number; it
is impossible, and the same row states six logged hours beside it. Before this
round the row was wrong in a boring way; now it contradicts itself.

**The documentation states the opposite of what the code does.** `SETUP.md` says
the new columns are appended "so that formulas pointed at the columns already
there keep working". Nineteen pre-round columns moved. The sentence was written
in this round, by this build.

**An approved fix pass exists and has not been started.** Sixteen parked
questions were ruled on by the human; eight code changes and six rewordings were
approved. None of them is in the tree, and the contract text on disk still says
things the human has already agreed to change.

---

## What I verified myself

Run twice, and by a reviewer independently: `node test/tests.js` → 908 passed, 0
failed. `node test/lint.js` → all clear, 20 rules, with all 17 pre-round rules
still present by name. `node test/headless.js` → ok, 20 checks per viewport,
seven phases. All four contracted timezones → 908/0. A fifth zone and a nonsense
zone → 880/0 with two sections skipped **by name**, no crash.

The pre-round baseline was re-measured from a clean checkout of `a256bdf`: 492
passed, 0 failed. The claimed starting line is real.

Per contract group:

- **Existing app unharmed (1-7).** Verified, with one correction to the record —
  see finding 4.
- **The day can end (8-12).** Verified by probes written against the harness
  rather than by trusting same-named tests: STOP closes both calendars at one
  instant and creates nothing; a lapsed confirmation queues nothing; nothing
  running is a clean no-op; the strip appears; a reboot finds no open event.
- **A guess says it is a guess (13-18).** Verified 13-17. **18 fails as
  written** — see finding 5.
- **The numbers (19-24).** Verified 19, 21, 22, 23, 24. **20 fails** — see
  finding 2.
- **It stops fighting you (25-29).** Verified. The sweep in assertion 28 was
  re-run independently at every second and at every 250 ms across 0-130 s, plus
  the exact millisecond boundaries: no elapsed time lets one unconfirmed tap
  change a block's category.
- **The small honesty fixes (30-31).** 30 verified. **31 half-fails** — see
  finding 6.

Things reviewers tried hard to break and could not: the offline queue (eight
taps, a sit and a STOP across three hours offline with a reload and forty
minutes of failed retries — eight taps, eight blocks, no duplicates, no loss);
reload in the middle of every multi-step flow; hostile input (500-character
notes, newlines, emoji and whitespace category names); a 30-hour block; midnight
crossings; a day with no events.

---

## Findings (worst first)

### 1. A forgotten STOP makes the sheet contradict itself — blocks shipping

**What happens.** The user logs six hours and forgets to press STOP. The next
morning the sheet reports **one** waking hour, and a sitting percentage of
**500**.

**How I proved it.** Driven end to end through the real client and the real
overnight guard, then re-run by hand:

```
09:00  tap SITTING, tap DW
10:00  tap MTG
       nobody taps again; open the app the next morning

ACTUAL : "DW: =" 09:00-10:00 | "MTG: ?" 10:00-15:00 | "UNLOGGED -" 15:00-07:30
SITTING: "SIT" 09:00-14:00

the daily row for 2026-07-20:
  waking h   1      sitting h  5      sitting %  5
  DW         1      MTG        5      UNLOGGED   9      switches 3
```

**Why.** Task A5 stopped `UNLOGGED` and `?` blocks from extending the waking
span — correctly, that was the round's own finding. But `sitting` still counts
every SIT hour in the day. The ratio then divides a full sitting total by a span
that no longer contains it. Five such days in a week aggregate to `waking h 5`
against `sitting h 25`.

The contract's own error case (A5: a day of only `UNLOGGED` leaves `sitting %`
blank) is honoured. Nothing in the suite ever divides a **real** sitting total
by a span that a `?` block has shortened.

**This survives the human's ruling on Q9.** Counting a guessed block's start
does not help here: the guessed block starts at 10:00, which is already inside
the span. It needs a decision of its own — see "Decisions for you", 1.

### 2. The documentation denies a break that the build shipped — blocks shipping

**What happens.** Every formula the user wrote in their own tab that points at a
column of `daily` or `weekly` **by position** now reads a different column.
Silently: no error, different numbers.

**How I proved it.** The live grid against the frozen pre-round record:

```
daily:  22 columns -> 65.  13 of 22 pre-round columns moved.
          plan DW   10 -> 11      switches 17 -> 19      waking h 18 -> 20
weekly: 28 columns -> 73.   6 of 28 pre-round columns moved.
          switches  23 -> 26      sitting % 26 -> 29
```

The mark columns from B2 and B3 *are* appended correctly. The movement comes
from D1 adding one key to the rollup, which inserts a column into every per-key
group. That was found during the build, escalated as Q14, and ruled on by the
human — the fixture stays frozen and contract 20 is reworded.

**What was missed is the documentation.** Two sentences in `SETUP.md`, both
written during this round:

- line 401: the new columns are appended *"so that formulas pointed at the
  columns already there keep working"* — false for the nineteen columns above.
- line 427: *"point formulas at `daily!A:Z`"* — `daily` is now 65 columns wide;
  `A:Z` covers 26 of them.

This is not a code fault. It is the build stating the opposite of what it does,
in the file the user is told to read.

### 3. The round's headline control is documented nowhere — should fix

`STOP` appears in no user-facing prose. `README.md`'s description of the marks
still lists three; `?` is used once in `SETUP.md` and never defined. Contract 24
only required the PLAN rule to be documented, so no assertion is broken — but the
user will find a new button on their phone and a new character in their calendar
titles with nothing to read about either.

### 4. The record's own integrity claim is false — should fix

`factory/progress-2.md` states: *"Exactly one pre-existing test assertion has
been removed all round."* Six assertion lines changed, across four commits:

```
d7cab0e  A2   'DW marked'                              expectation = -> ?   DISCLOSED
e76e566  C1   'a tap 20s later writes nothing yet'     renamed to 10s       cosmetic
e76e566  C1   'the new one is on the shelf too...'     replaced             NOT DISCLOSED
f9b4d50  B2   'exactly one new column' + 'the only
              thing in it is the stamp'                replaced             disclosed (Q11)
7a0edf1  D1   'the same run still reports the same
              shape' + the two above, again            replaced             disclosed (Q14)
```

The undisclosed one is in the set-aside drawer, which contract 7 names as
untouched-and-still-behaving-as-its-tests-assert. **The code there is not
weaker**: C1's window change made the old assertion impossible to pass, and the
two that replaced it pin the drawer against the shelf exactly and require it to
have grown. The defect is in the sentence, not the drawer. But it is false about
precisely the number a reviewer uses to decide how hard to look.

Two more headline claims are wrong in the same way: the summary says *"no
circuit breaker fired"* when one did for D2 (conceded five hundred lines below
it), and *"two criteria are unmet"* when three are — criterion 6 of task A1 is
the third, and its own section says so.

### 5. One title does not survive being written again — should fix

```
"UNLOGGED ?"  ->  parsed  ->  rebuilt  ->  "UNLOGGED: ?"
```

Contract 18 says **any** title carrying `?` round-trips byte-identical. This one
gains a colon. It predates the round and is identical for every mark. The human
has ruled (Q6): make the title stable rather than reword the contract.

### 6. `week of` holds text, not a date value — should fix

Contract 31 and D2's criterion 4 say the cell "is still a date value, not a
string". It is a string, and the round-1 fixture proves it was one before this
round. The human has ruled (Q16): keep the text, reword the criterion.

### 7. A note ending in a space and a question mark is silently deleted — should fix

**What happens.** The user types `is this right ?` in a block's note. The `?`
disappears from the note and nothing says so. A note of only `?` becomes empty.

**New this round.** Before it, that note round-tripped intact. Task A1 made `?` a
mark, so `buildTitle_` now removes a trailing `?` from the user's own text to
keep contract 17 true — a block the user annotated must not become
indistinguishable from one the app guessed. Contract 17 is satisfied and the
user's typing pays for it. The human's ruling on Q2 extends the same deletion to
`+`, `=` and `-`, which makes this four characters instead of one.

### 8. An armed STOP covers the posture toggle — should fix

**What happens.** The user reaches for SITTING, misses, and hits STOP at the edge
of the row. The armed state takes the whole row. They tap again where SITTING
was — and end the day.

```
resting:  postureBtn 228x64 at x=12    stopBtn  79x64 at x=299
armed:    stopBtn   366x64 at x=12, position:absolute   (covers the row)
a tap at the posture toggle's centre while armed -> the day ends
```

This is deliberate: task A4 wanted the armed label unmissable, and the headless
check exempts a covering element from its overlap rule. But no test asks what a
tap at the *posture toggle's* coordinates does while STOP is armed, and the
reflex for cancelling an accidental arm — tap somewhere else — is, in that row,
the confirm.

### 9. A block the app cannot read is invisible, but the grid still looks busy — should fix

With an open block whose title was hand-edited to something unreadable: no cell
is lit, no clock is shown, and the grid does **not** enter its idle state,
because something is genuinely open. `Index.html` says of that veil: *"mistaking
idle for running is the one failure that puts a hole in the record."* This is
that failure approached from the other side. Recovery works — a tap on any
category closes the block correctly — but nothing tells the user there is
anything to recover. The human ruled on the repair path (Q15: leave it); this is
the visual half, which was not put to them.

### 10. Two devices: an ended day can be silently re-opened — should fix

Phone ends the day at 22:00 with STOP. A laptop tab left open still shows the
block running. Two hours later a tap on the laptop rewrites the closed block's
end from 22:00 to 00:00 — two hours that never happened, on the calendar and in
the rollup, with neither screen saying anything.

The mechanism is round-1 code (`opCloseActual_` moves the end time
unconditionally) and a hand edit in Google Calendar does the same. But "the day
is over" is a state that did not exist before this round, and a desktop tab that
is never hidden never re-reads.

### Cosmetic

- The set-aside banner says "gave up on **one** write" however many were set
  aside; the drawer shows them all.
- A double tap on SITTING writes a 12-millisecond SIT event. Pre-existing.
- A single `UNLOGGED` event can span 25 hours across two days. Pre-existing.
- `switches` counts `UNLOGGED` and `UNFILED` events, so the forgotten-STOP day
  above reports three switches for two taps.

---

## Parked work

Nothing was parked, and the circuit breakers did not stop the run. Two tasks
were marked done while carrying an unmet criterion (D1 and D2), and a third
carries one that its own section admits is not met (A1's criterion 6). All three
are disclosed in their own sections; the summary's count of them is wrong, which
is finding 4.

The sixteen questions parked during the build have all been ruled on by the
human. Eight code changes and six rewordings are approved and not yet started.

---

## Decisions for you

Only genuine open decisions are here. Everything above is a fact and needs no
ruling.

1. **The forgotten-STOP day (finding 1).** What should `sitting %` say when the
   waking span no longer contains the sitting hours? Recommendation: count only
   the sitting time that falls **inside** the waking span, so the column means
   "of the time you accounted for, how much did you sit". `sitting h` keeps the
   true total.
2. **A note that loses its last character (finding 7).** Keep the silent
   deletion, tell the user, or let the note keep the character and accept that
   it reads as a mark? Recommendation: keep the deletion, and say so in the
   documentation the round already owes.
3. **The armed STOP covering the row (finding 8).** Keep the unmissable armed
   state, or leave the posture toggle uncovered? Recommendation: keep the label
   large but stop it covering the posture toggle.
4. **The invisible unreadable block (finding 9).** Recommendation: say it in the
   banner that already exists, rather than build a new control.
5. **The two-device re-open (finding 10).** Recommendation: a close refuses to
   move the end time of a block that is already closed.
