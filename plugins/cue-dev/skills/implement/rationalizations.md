# Common Rationalizations

Excuses that show up mid-loop, and what is actually true. Referenced from
[SKILL.md](SKILL.md) and from both procedure files.

The rows about reviewers, rounds and dispatches belong to
[independent-review.md](independent-review.md); the rows about rows and reports
apply to both. Each procedure file carries the ones that are only its own.

| Excuse | Reality |
|--------|---------|
| "Close enough on spec compliance" | Reviewer found spec gaps = not done. Fix or hit the cap and adjudicate — those are the only exits. |
| "I'll fix it myself, dispatching is overhead" | Controller fixes pollute your context and skip review. Resume the implementer. |
| "One more round will converge" | Past the cap, rounds don't converge — the failure is structural. Adjudicate and route. |
| "The reviewer will just find something new anyway" | Scoped re-reviews verify fixes; they cannot wander. New findings on untouched code become parked minors, not another round. |
| "This finding is obviously wrong, I'll drop it" | You adjudicate only at the cap, and every ruling goes into the task's row. Silent discards are forbidden. |
| "The fix was small, skip the re-review" | Unreviewed fixes are how regressions land. Every round ends with a scoped re-review. |
| "Reviews slow the loop down" | The loop without reviews is just unverified churn. Reviews are the loop's brakes and steering. |
| "Committing each row is overhead" | The committed row is what survives compaction and a subagent's cleanup. Controllers without a durable record have re-dispatched entire completed task sequences. |
| "I'll write outcome.md all at once at the end" | By then you no longer remember what changed or why. What you get is a summary copied off the commit list. Write each task's row where it happens. |
| "The reports have it all, so skip the outcome" | The reports are scratch that gets deleted with the workspace (`.cue/dev/sdd/`); outcome.md is the result that stays in the PR. |
| "Nothing notable here, I'll leave this row blank" | `as-planned` is a record too. `unrecorded` reads as "not done". |
| "Let me write down every review finding" | What was fixed leaves no trace. Record only what survives the fix. |
