# Review: the Day Rail redesign — 2026-07-28

Reviews 1 and 2 are round 1's (`REVIEW.md`, `REVIEW-2.md`). Review 3 is round 2's
(`REVIEW-3.md`). This is the fourth, and the first of the redesign.

**Under review:** `3e2c87d..4b26e0a` — two commits implementing design 2a from
`~/Downloads/design_handoff_dayrail_redesign/` (README plus an interactive
prototype). The extracted, readable prototype is at
`scratchpad/prototype-2a.html`; section 2a is at line 555 and its runtime
values at 1267–1376.

**How it was run.** Three independent reviewers, none given the builder's
reasoning: one on fidelity to the handoff, one on what the refactor broke, one
on how it fails a user. Each measured rather than read. The three blocking
faults below were then **reproduced by hand** before being written down.

---

## Verdicts

| Reviewer | Verdict |
|---|---|
| what the refactor broke | **BROKEN** |
| how it fails a user | **NOT DONE** |
| fidelity to the design | **MINOR DRIFT** (surface area, not severity) |

**The build does not ship.** The redesign's whole claim is that nothing is lost
to one tap, because every switch can be undone for five seconds. Four findings
break that claim in ordinary use, and all four break it silently.

---

## Blocking

### B1. Undo does nothing while the write is still travelling

The user taps the wrong category, taps UNDO a second later, and the screen says
it worked: the panel shows the old block, the queue empties, the header reads
`GOOGLE CALENDAR · SYNCED`. The calendar keeps the mistake. Every later tap
files work under the wrong category, and a reload brings the mistake back.

```
mis-tap MEETINGS, UNDO one second later, 1200ms round trip
  after UNDO, queue: []          the app says: running DW
  CALENDAR:  "DW: =" 09:00-09:40 | "MTG:" 09:40 OPEN
  after a reload the app shows:  MTG
```

`dropOps` (`Index.html`) removes queue entries by id with **no `flushing`
guard**, then `takeUndo` reads "both found" as "the calendar never saw this" and
sends no compensating op — while the server is applying both.

**This is a repeat.** Round 2 found this exact hazard, wrote it up as
`progress-2.md` addition 4, and fixed it in `mutatePendingOpen` with a guard and
a comment naming it. The new function was written without the guard.

It fails for every round trip except an impossible 0 ms. Apps Script takes
0.5–2.5 s. Measured broken at 100, 300, 600, 1200, 2500 and 4000 ms.

**Why 970 assertions miss it:** every undo test settles the flush before tapping
the ribbon. The one test of this shape — `52k`, driven by
`H.setCallLag('applyOps', 30000)` — was deleted with the mechanism it covered,
and no successor was written. Its twin `52j` survived because it covers a path
that was kept.

### B2. The guardrail leaves the screen at seven categories

Measured in Chromium at 390×844, after a switch:

```
categories=6    ribbon visible 56 of 56 px   a tap at its centre hits: undo
categories=7    ribbon visible 56 of 56 px   a tap at its centre hits: postureBtn
categories=8    ribbon visible 45 of 56 px   a tap hits nothing
categories=10   ribbon visible  0 of 56 px   the ribbon is off the screen
```

At seven categories a tap where the ribbon appears **toggles sitting and writes
a block**. At ten — `MAX_CATEGORIES`, which the Add row invites the user
towards — the undo is gone entirely, and so are the mark buttons.

### B3. Undo never puts back the sitting it closed

```
sitting, then a mis-tap on BODY:   SIT closed
UNDO:                              work block back, SIT still closed
                                   footer says NOT SITTING while the user sits
```

Same on the STOP path. `tapCategory` and `endDay` both call `closeSit`;
`takeUndo` has no sitting branch.

### B4. The one coupling is broken on the undo path

The handoff names it explicitly: *"opening Body (by tap, split remainder, **or
undo**) closes any open SIT block."*

```
BODY running -> switch away -> sit down -> UNDO
  BODY open: true   SIT open: true    <- a state the model forbids
```

The deleted section `50g` existed to prove this coupling survives whatever
replaces the tap. Deleted, no successor, successor path broken.

### B5. STOP still arms and confirms

The handoff's overview: guardrails are *"undo instead of arm/confirm"*. Its STOP
paragraph: STOP closes the block, and *"Undo restores the stopped block."* The
prototype's `stopF()` closes immediately.

The build kept arm-and-confirm on STOP: the first tap arms and fills solid red,
the second ends the day. The pattern the redesign exists to remove survives on
the most destructive control in the app.

---

## Should fix

**Copy and type**

1. Raw internal keys shown to the user in four places: SPLIT kicker
   (`OPEN BLOCK: DW`, spec `OPEN BLOCK · DEEP WORK`), SPLIT sub-copy, the mark
   strip, and the set-aside row. `faceOf()` exists and is used correctly in the
   grid, the NOW panel, the rail and the undo label — these four never route
   through it.
2. **`font-variant-numeric: tabular-nums` is defeated on every clock but one.**
   The `.tnum` class is applied correctly throughout, and each rule then sets
   the `font:` **shorthand**, which resets font-variant. Only `#undoChip`
   survives, because it has no shorthand. The 48px headline timer is affected.
3. SPLIT lists the running category. The comment above the loop says *"the same
   list, minus the block you are cutting"*; the loop has no filter.
4. The mark strip label is truncated: an 83px box for 111px of the current
   (wrong) text, 159px of the correct text. Three 44px buttons leave too little
   room in a 250px column.
5. The SET ASIDE title is missing its count (`SET ASIDE · n`).
6. The SIT sub-copy reads `16m sitting`; the spec says `sitting for 16m if
   applied`.

**Correctness**

7. `opUndoSwitch_` refuses to delete a new block that has moved or closed, then
   reopens the previous one regardless — leaving **two open blocks**, which the
   model forbids. Reopening must be conditional on the delete having happened.
8. `doSplit` never calls `railClosed`, so after a split the rail draws the first
   half as time nobody logged until the next page load.
9. Overlapping blocks (a hand edit, or two devices) produce a phantom hatched
   gap: `paintRail` keeps one `prevEnd` and assumes blocks never overlap.
10. `S.today` is persisted by `saveState` — against both the code's own comment
    and the handoff's *"No new persistent state"* — and grows without bound
    offline (119 entries / 10KB after 120 switches). Nothing reads it back.
11. STOP + undo always emits a compensating op: `dropOps([closeId, null])` can
    never return 2, so the `dropped < 2` test always passes. Harmless, but it is
    the accidental reason STOP escapes B1.
12. The set-aside drawer prints an epoch date for a missing start
    (`isFinite(null)` is true) and the raw word `undoSwitch` — `OP_WORDS` has no
    entry. `quarantine` clears the grid for a set-aside open but not for a
    set-aside undo.

**Reach and layout**

13. The undo ribbon has no `role`, no `tabindex`, no keyboard handler and no
    `aria-live`. It is not in the tab order. The handoff says to preserve the
    accessibility patterns already present, and the arm-and-confirm it replaced
    **was** keyboard-operable. A keyboard user traded a working guardrail for
    nothing.
14. The rail outgrows its box: `RAIL_PX = 340` against a ~517px box, with a 26px
    floor per segment and no total budget. 20 blocks overflow; 40 blocks put the
    last segment at y=1310 on an 844px screen and scroll the category column off
    the display.
15. The Add row is now the row nearest the thumb. `layoutCells()` exists to
    prevent exactly this and is never called; its comment still states the rule
    it no longer enforces.
16. No dead zone between the ribbon's bottom edge (758) and the sitting toggle's
    top edge (760). Posture has no undo, so a stray tap splits an hour of
    sitting into two blocks with a permanent seam.
17. A double tap on the running row — which round 1 taught users to do — opens
    SPLIT, and `openSplit` clears the undo deliberately. The way back is gone
    for good.

**Behaviour**

18. The natural repair of a mis-tap — tapping the right category again — now
    costs the block. One level of undo, no merge. The old retitle rule existed
    for this; its code is still in the file and nothing calls it.

**Tests**

19. Deleted assertions that covered behaviour which still exists:
    - `52k` — the only lagged-flush test of client-side queue surgery (B1).
    - `50g` — the Body↔SIT coupling on the successor path (B4).
    - `50f` "THE SWEEP" — no single tap at any second changes an existing
      block's key. Still true, now stronger, and asserted nowhere. Section 66's
      claim that *"every assertion the arm/confirm sections used to make is now
      made here"* is **not accurate**.
    - "an unlit box cannot write a note" — the property survives as
      `$('note').disabled = !open` and is untested.
20. Dead code shipped to every phone: `arm()`, `willRetitle()`,
    `confirmLabel()`, `CONFIRM_RETITLE/SWITCH`, the `armed` variable,
    `colsFor()`, `layoutCells()`. `clientConfig_` still ships `mistapSeconds`
    and `confirmWithinSeconds`, and `test/lint.js` still enforces a rule about a
    client mechanism that no longer runs. `#syncN` is written but permanently
    hidden.
21. `test/harness.js` `INIT_CLS` has no `undo` entry, so after `reboot()` the
    shim reads the ribbon as visible. Harness-only, but it means no assertion
    can catch a ribbon left up on load.
22. The rail has no text equivalent: no role or label, gap segments carry only a
    duration, so "hatched means unlogged" is carried by colour alone.

---

## Cosmetic

- Past midnight without a reload the rail draws two days as one.
- A 30-second block is written and drawn as `0m`.
- The undo chip sits on `1` for about 1.3s and never shows `0`.
- Undo discards a mark the user tapped a moment earlier. Self-repairing.
- `pump()`'s return value is discarded at every call site, so a too-low cap
  fails silently at the *next* assertion.

---

## What is right, for calibration

All 12 design tokens are hex-exact, as are all 11 category swatches. Every
weight, size and letter-spacing checked computed exactly, to the hundredth of a
pixel. Zero border-radius everywhere. The font is genuinely self-hosted — 35KB
of woff2, base64, weights 100–900 — with **zero** network requests beyond the
initial navigation. The day rail's geometry matches the prototype's own `rail()`
function exactly, not merely the README's prose. The header's three sync states,
both undo ribbon strings and the error banner are byte-exact.

Undo is exactly right in both clean cases: fully queued, and fully landed. The
compensating op is idempotent on replay, handles a deleted block, a stale replay
and a ref collision. The close that must not stretch an already-closed block
still holds. DISCARD in the drawer still arms and confirms, and the
sliding-row hazard stays pinned.

Measured, twice, in four timezones: **970 passed / 0 failed**, lint all clear,
headless ok at 21 checks per viewport. The suite is green and it is not enough —
which is the finding that matters most.

---

## Decisions for you

Only genuine open questions are here; everything above is a fact.

1. **B5 — STOP.** The handoff says STOP acts at once and undo restores it. The
   arm-and-confirm on STOP came from round 2, where you ruled on it twice.
   Follow the handoff, or keep the confirm on the one control that ends the day?
   Recommendation: follow the handoff. Undo now covers it, and keeping both
   guardrails on one control is what makes the ribbon feel like furniture.
2. **Finding 18 — the mis-tap repair.** Restoring a merge (tapping the right
   category again rejoins the block) is real work and is not in the design.
   Recommendation: leave it out for now, and see whether it hurts in use.
3. **Finding 15 — the Add row.** The design puts Add at the end of the list;
   round 1 put it furthest from the thumb for a reason. Recommendation: follow
   the design, and note the rule is now carried by the design rather than by
   `layoutCells`.
