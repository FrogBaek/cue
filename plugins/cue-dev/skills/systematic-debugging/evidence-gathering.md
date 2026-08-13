# Gathering Evidence Across Component Boundaries

Phase 1, step 4 of [SKILL.md](SKILL.md). Use this when the system has several
components and you do not yet know which one fails — CI → build → signing,
API → service → database, request → queue → worker.

## The procedure

Before proposing any fix, add diagnostic instrumentation:

```
For EACH component boundary:
  - Log what data enters component
  - Log what data exits component
  - Verify environment/config propagation
  - Check state at each layer

Run once to gather evidence showing WHERE it breaks
THEN analyze evidence to identify failing component
THEN investigate that specific component
```

One run with instrumentation at every boundary beats several runs each guessing
at one layer. You are not trying to fix anything yet — you are narrowing which
component to investigate.

## Worked example: a four-layer signing pipeline

```bash
# Layer 1: Workflow
echo "=== Secrets available in workflow: ==="
echo "IDENTITY: ${IDENTITY:+SET}${IDENTITY:-UNSET}"

# Layer 2: Build script
echo "=== Env vars in build script: ==="
env | grep IDENTITY || echo "IDENTITY not in environment"

# Layer 3: Signing script
echo "=== Keychain state: ==="
security list-keychains
security find-identity -v

# Layer 4: Actual signing
codesign --sign "$IDENTITY" --verbose=4 "$APP"
```

**This reveals** which layer fails — for instance secrets → workflow ✓ but
workflow → build ✗, which tells you the propagation broke between layers 1 and
2, and that layers 3 and 4 were never the problem.
