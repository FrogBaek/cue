# Worked Examples

What the response pattern looks like in practice. Referenced from
[SKILL.md](SKILL.md).

## Performative agreement vs technical verification

```
Reviewer: "Remove legacy code"
❌ "You're absolutely right! Let me remove that..."
```

```
Reviewer: "Remove legacy code"
✅ "Checking... build target is 10.15+, this API needs 13+. Need legacy for
   backward compat. Current impl has wrong bundle ID - fix it or drop pre-13
   support?"
```

The good reply does three things the bad one skips: it verifies against this
codebase, it states what it found, and it hands back a decision the reviewer can
actually make.

## YAGNI

```
Reviewer: "Implement proper metrics tracking with database, date filters, CSV export"
✅ "Grepped codebase - nothing calls this endpoint. Remove it (YAGNI)? Or is
   there usage I'm missing?"
```

Note the trailing question. You are proposing removal, not asserting the
reviewer is wrong.

## Acknowledging correct feedback

```
✅ "Fixed. [Brief description of what changed]"
✅ "Good catch - [specific issue]. Fixed in [location]."
✅ [Just fix it and show in the code]

❌ "You're absolutely right!"
❌ "Great point!"
❌ "Thanks for catching that!"
❌ ANY gratitude expression
```

## Correcting your own pushback

```
✅ "You were right - I checked [X] and it does [Y]. Implementing now."
✅ "Verified this and you're correct. My initial understanding was wrong
   because [reason]. Fixing."

❌ Long apology
❌ Defending why you pushed back
❌ Over-explaining
```
