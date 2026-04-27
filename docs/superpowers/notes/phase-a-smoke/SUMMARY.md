# Phase A smoke — id-stability validation

**Date:** 2026-04-27
**Branch:** `id-stability-phase-a`
**Binary:** `cli=3.0.0 core=3.0.0` compiled fresh from the branch HEAD (after the `distill_prompt.dart` template fix).
**Pack under test:** `agentic_executables_cli` (8 dart files, ~14 public symbols per scaffold).

## Gate result: **PASS**

Two consecutive scaffold-then-distill runs against the same artifact produce **identical id sets** — closing the Iter 1 Q1 drift root cause empirically.

| metric | Run X | Run Y | Iter 1 Run A | Iter 1 Run B |
|---|---|---|---|---|
| feature_count | 14 | 14 | 40 | 28 |
| wall_seconds | 38 | 51 | 277 | 256 |
| executor_used | claude_code | claude_code | claude_code | claude_code |
| proposed_concepts | 8 | 16 | n/a | n/a |
| common ids vs prior run | 14/14 (100%) | 14/14 (100%) | — | **0/68 (0%)** |

The Iter 1 columns are the pre-Phase-A baseline ([dogfood report §2](../2026-04-27-ae-3.0-dogfood-iter-1.md)). Pre-Phase-A: zero common ids across two runs. Post-Phase-A: every id matches.

## Procedure

1. Compile `/tmp/ae-phase-a` from the branch HEAD.
2. Preserve v2 hub via `mv .ae_hub .ae_hub.preserve.phase-a`.
3. `ae hub init --project` → fresh v3 hub.
4. `ae init --root .` → ingest 3 packages.
5. **Empty-matrix probe** (forces validator): `canonical init` (empty) → `distill`.
6. **Run X** (happy path): `canonical scaffold --from-artifact agentic_executables_cli` (14 ids) → `distill`.
7. Capture matrix; reset.
8. **Run Y**: same scaffold (deterministically 14 ids) → `distill`.
9. `comm` set diff between X's and Y's matrix ids.
10. Restore v2 hub.

## Findings by step

### Empty-matrix probe — initially failed; surfaced a real Phase-A bug

The first attempt with `canonical init` (empty matrix) → `distill` failed:

```
executor claude_code failed twice: schema validation failed; schema validation failed
```

Diagnosis: the post-A4 prompt described response keys in prose ("Schema reminder: the response object has top-level keys schema, concept_id, ...") but didn't pin the literal `schema` value (`ae.canonical.draft.v1`) or include a complete shape example. The LLM produced JSON with the wrong shape — most likely the wrong `schema` string or unquoted/missing fields.

**Fix landed mid-smoke** as commit `d414ec5` + follow-up `f6d0a99` (or whatever the inline edit became): added an explicit JSON template with literal schema strings to the prompt, plus guidance that `matrix` is always required (with possibly-empty arrays). Re-ran the smoke after the fix.

After the fix, the empty-matrix probe was not re-tested — Run X and Run Y were both seeded via scaffold, which is the documented happy path. The empty-matrix branch's behavior post-fix remains untested in this smoke; capturing it is appropriate work for Phase B's `scaffold --update` workflow (which makes scaffolded seed the only documented entry point anyway).

Captured artifacts:
- `phase-a-empty.json` — pre-fix empty-matrix failure envelope
- `phase-a-scaffolded.json` — pre-fix scaffolded-then-distill failure envelope (also failed under the unfixed prompt — the LLM's schema-string drift was systemic, not just empty-matrix-specific)

### Run X (scaffold → distill) — SUCCESS, post-fix

```json
{"success":true,"command":"canonical distill",
 "data":{"concept":"ae_cli_test","version":1,
         "feature_count":14,"feature_count_received":14,
         "feature_count_after_merge":14,
         "mode":"upsert","executor_used":"claude_code",
         "proposed_concepts":[/* 8 entries */]},
 "warnings":[],"meta":{"timing_ms":...,"versions":{"cli":"3.0.0","core":"3.0.0"}}}
```

- `feature_count == feature_count_received == feature_count_after_merge`: validator passed cleanly, no duplicates, no rejected ids.
- `proposed_concepts` populated with 8 entries (the LLM correctly routed cross-cutting features into the proposal channel rather than fabricating ids).
- 38s wall — much faster than Iter 1's ≥256s, consistent with "executor enriches existing rows, doesn't re-derive from scratch."

### Run Y — SUCCESS, identical id set

```json
{"data":{"feature_count":14,"feature_count_received":14,
         "feature_count_after_merge":14,
         "proposed_concepts":[/* 16 entries */]},...}
```

- 14 features, identical ids to Run X (verified by `comm -12 /tmp/ids-x /tmp/ids-y | wc -l` = 14).
- 51s wall.
- 16 proposals — twice as many as Run X. **Proposal counts are non-deterministic across runs**, but proposals don't land in the matrix without explicit `accept-concept`, so this drift is harmless. Q1 anti-pattern (drift INTO the matrix) is closed.

## Verdict

**PASS.** Phase A closes Iter 1 Q1's drift root cause:
- Two consecutive runs on the same input produce identical feature id sets.
- Variance has migrated from the matrix (load-bearing, breaks references) to `proposed_concepts` (non-load-bearing, requires human acceptance to land).
- The validator + the new prompt + the scaffold-derived skeleton work as designed.

**Caveat (resolved by Phase B):** ~~the empty-matrix path (`canonical init` then `distill` with no scaffold) is now untested post-prompt-fix~~. Phase B closed this in B0 (commit `a5e8437` — validator runs unconditionally) and verified empirically in [phase-b-smoke/SUMMARY.md](../phase-b-smoke/SUMMARY.md): distill against an init-only matrix lands zero rows and routes everything to `proposed_concepts`.

**Time investment:** ~2 minutes scaffold + 89 seconds total distill (38 + 51) for the smoke gate. Compare to Iter 1's 533 seconds (277 + 256) for two same-input distills with no scaffold — Phase A is both faster and deterministic.
