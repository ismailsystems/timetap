# Factory State
project: timetap
stage: 5
stage_name: The loop builds it
last_updated: 2026-07-26 19:20
next_action: Human launches the overnight loop from factory/HANDOFF.md (orientation prompt first, then "begin"). When it finishes, run /factory for the fresh-eyes review.
notes: |
  HANDOFF.md is compiled and self-contained. progress.md and log.md are seeded so
  the loop's first GATHER finds them. The factory does NOT launch the loop — the
  human presses the button.

  Branch factory/error-paths created off main and checked out. factory/ is
  untracked at launch; the loop's first commit will sweep it in.

  Baseline verified green immediately before handoff: 298 assertions under
  America/New_York, Europe/London, Australia/Sydney, UTC; lint all clear.

  Caps set in HANDOFF.md: 25 passes or 8 hours; 3 failures parks a task; 3 parked
  tasks ends the run.

  Round scope: three error-path features — (1) drawer for set-aside writes,
  (2) rollup that records its own failure, (3) headless smoke test. Ordered cheap
  first (B, C) so a partial night still delivers; D is where a stall is expected.

  Highest-risk task is D4 (drift lint between the meta tags doGet injects and the
  ones the headless harness injects), carrying a mandatory meta-test: replacing the
  rule with one that always returns true must break at least three of its own
  criteria.

  A1 carries a standing instruction: if its assertions about EXISTING behaviour fail
  against unmodified code, that is a finding to record and PARK — not a reason to
  edit Index.html until green.

  Corrections made during stages 3-4, both already applied to BRIEF/PLAN/GUIDE:
    - doGet adds THREE meta tags (Code.gs:180-182), not four. Four is the allowlist
      of names Apps Script permits.
    - The real assertion count is 298, not the 253 test/README.md claims. Contract
      assertion 1 pins 298; fixing the doc is a criterion in E1.

  Plan explained to user 2026-07-26 (factory/GUIDE.md Part 1, post-office scene).
  Part 2 gets written after the review.

  When the loop is done: /factory → stage 6 → factory-review. The review must read
  ONLY the contract and the diff, never the loop's reasoning.

  Product law that must survive any build: automate capture, never automate
  judgment. Non-goals in README.md are binding.
