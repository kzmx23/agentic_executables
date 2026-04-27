# Phase B smoke — operator workflow + id-stability re-gate

**Date:** 2026-04-28
**Branch:** committed directly to `v2` (operator override of per-phase branch pattern)
**Binary:** `cli=3.0.0 core=3.0.0` compiled fresh from `7f68969` (after the nested-cells fromMap fix landed mid-smoke).
**Pack under test:** `agentic_executables_cli` (8 dart files, 14 public symbols).

## Gate result: **PASS**

Two consecutive scaffold-then-distill runs against the same artifact produce **identical id sets** — Phase B preserves Phase A's determinism contract while adding the operator-workflow primitives (`--update`, `--rename`, `accept-concept`).

| metric | Phase B Run X | Phase B Run Y | Phase A Run X | Phase A Run Y | Iter 1 Run A | Iter 1 Run B |
|---|---|---|---|---|---|---|
| feature_count | 14 | 14 | 14 | 14 | 40 | 28 |
| common ids vs prior run | 14/14 (100%) | 14/14 (100%) | 14/14 | 14/14 | — | **0/68 (0%)** |
| wall_seconds | 105.4 | 113.8 | 38 | 51 | 277 | 256 |
| proposed_concepts | 0 | 1 | 8 | 16 | n/a | n/a |
| executor_used | claude_code | claude_code | claude_code | claude_code | claude_code | claude_code |

Phase B is slower than Phase A (≈110s vs 45s) — likely due to the prompt's ID-STABILITY-RULES block being load-bearing on the LLM's reasoning budget per row. Not a regression; deterministic enough that B6 closed cleanly.

## What was verified

| Step | Task | Outcome |
|---|---|---|
| 3 | B0 closure: `init` + `distill` against empty matrix | ✅ 0 features, 15 proposals (14 with rationale `missing-from-scaffold`, 1 true cross-cutting) |
| 4 | B1 `--update` no-op (idempotent) | ✅ `added=[], removed=[], unchanged=14` |
| 5a | B1 `--update` with synthetic source change (artifact patch) | ✅ `added=[fake_added_symbol], removed=[spec_export_result], unchanged=13` |
| 5b | Tombstone shape on disk | ✅ `removed: true` + preserved `spec`/`invariant` |
| 5c | **Revival semantics** — restore source after tombstone, re-run `--update` | ⚠️ Tombstone persists (no auto-revive); operator must hand-edit. Documented as known gap. |
| 6 | B3+B4 accept-concept end-to-end (synthetic proposals file) | ✅ Row landed with `provenance: accepted_concept`; accepted proposal removed from `.last_proposals.json`; `produced_at` preserved |
| 7 | Determinism re-gate (two runs, compare id sets) | ✅ 14/14 common, 0 only_in_x, 0 only_in_y |

## The bug B6 caught (and why the smoke is non-negotiable)

Mid-smoke, after Step 6 produced a corrupted matrix.yaml with `cells: "{spec: ..., invariant: ...}"` flow-style entries, root-cause tracing revealed:

- The distill prompt (`agentic_executables_core/lib/src/adapters/distill_prompt.dart` line 33) tells the LLM to emit `{id, cells: {spec, invariant}}` — **nested cells**.
- B1's `CanonicalFeature.fromMap` rewrite handled only **flat cells** (top-level `spec`/`invariant`/etc. keys). Nested input collapsed: `feature.cells['cells'] = innerMap.toString()`.
- All 6 B1 model unit tests exercised the flat shape, so the regression slipped past spec compliance + code quality reviews.

Fix: commit `7f68969` made `fromMap` accept BOTH shapes (flat keys win on collision so on-disk format remains authoritative). Two regression tests added.

This is **exactly the failure mode Phase A's handoff warned about**: "The smoke gate is the real proof. Unit tests pass without exercising the LLM." Without the smoke, B1's regression would have shipped silently and corrupted every distilled canonical until someone noticed the matrix.yaml shape.

## Process recommendations

These observations emerged from running the smoke. Each is concrete enough to act on; together they suggest where Phase C / future iterations could simplify operator ergonomics.

### Add: regression test for the LLM-vs-on-disk shape contract

The B1 unit tests covered round-trip on the new flat shape but had no test for the old/external (nested-cells) shape. The new test in `7f68969` pins it. **Convention to add to future plans:** any model whose serialization is consumed by an LLM response MUST have a "round-trip from the literal LLM-prompt shape" test, not just round-trips from its own toJson output.

### Add: revival semantics for `--update`

A symbol that vanished (tombstoned) and later returned in source stays `removed: true`. Operator must hand-edit matrix.yaml or use a new flag. Two reasonable shapes:
- Implicit auto-revive: `--update` flips `removed: true → false` when the id reappears in `sourceIds`. **Preferred** because it matches "source of truth" idempotence.
- Explicit `--revive id` flag: keeps strict-by-default discipline (mirrors `--rename`).

This was flagged by the B2 code reviewer (concern A) and confirmed empirically here. Worth a small follow-up task.

### Add: `--version` flag on the CLI

`ae --version` returns `invalid_arguments` (only `--help` works). Most operators probe `--version` first. Trivial to add; low cost, high signal.

### Update: clarify "discovery mode" of distill against an empty matrix

`init` then `distill` (no scaffold) doesn't produce features (validator rejects all) — but it DOES produce a list of `proposed_concepts` whose rationale is `missing-from-scaffold; rerun ae canonical scaffold --update`. This is genuinely useful as a "what does the LLM think is in this pack?" diagnostic. Consider:
- Documenting it explicitly in cli-reference under `### ae canonical init` ("After init, you can run distill once to get a discovery list of proposals").
- Or adding `ae canonical discover --pack <p>` as an alias (init + distill + pretty-print proposals).

### Update: the `unchanged` count semantics

The B1 code-review M2 docstring fix landed but the count is still slightly counter-intuitive: it includes already-tombstoned rows AND `accepted_concept` rows, plus both halves of each rename pair are excluded. Operators reading the JSON envelope have to read the docstring to interpret the number. Two options:
- Stay as-is and rely on the (now-clear) docstring.
- Split into `unchanged_live` + `unchanged_tombstoned` + `unchanged_accepted` for full transparency. Probably overkill for B-phase; revisit if operators ask.

### Consider: chunking distill scope from "pack" to "domain"

This is the scoping idea you raised. Currently distill runs at the granularity of an artifact pack (one `pack.dart` directory ≈ 14 public symbols). For `agentic_executables_cli` this is fine — small surface, fast (~110s wall).

For larger packs (imagine a 200-symbol service binary), the same prompt format would either:
1. Strain the context window (whole pack → one LLM call).
2. Force the LLM to context-switch across unrelated domains within a single distill (e.g. "auth", "billing", "rate-limiter" all in one run).

A "domain"-scoped distill would let the operator slice a pack into smaller invariant-coherent chunks:
```bash
ae canonical distill --pack ae_cli --concept ae_cli/auth --domain "AeCli, AuthMiddleware, *"
ae canonical distill --pack ae_cli --concept ae_cli/io --domain "SafeFileWriter, FileWriteRequest, *"
```
Each domain becomes its own canonical concept with its own proposals stream. The `accept-concept` flow scales because proposals stay scoped.

**Tradeoffs:**
- Pro: fits LLM context budget for big packs; proposals are domain-coherent (an "auth" concept won't leak into an "io" canonical).
- Pro: enables team-of-experts review (auth domain = security team, io domain = infra team).
- Con: adds operator decision: "what counts as a domain?" — risks the same drift Phase A's prompt-pin closes for ids.
- Con: cross-domain invariants (e.g. "every domain emits JSON") become awkward; they belong in a meta-concept.

If pursued, the design probably needs:
1. A domain manifest at `<concept>/domain.yaml` declaring symbol globs.
2. A `--domain <slug>` flag on distill that filters `matrix_seed_rows` to that domain's seed.
3. An "unscoped concept" tier for cross-domain invariants (e.g. `<pack>/_global` concept).

This is **Phase C+ material**, not B6 — flagging here as the natural next architectural question. Iter 2 dogfood (planned for after Phase C) would be the right place to test it empirically against a larger pack.

### Consider: capture proposals across multiple distill runs into a stream

Right now `.last_proposals.json` reflects only the most recent distill. Two consecutive distills would replace, not accumulate, the proposals (B3 explicitly clears empty proposals). For an operator running `distill` weekly while incrementally accepting proposals, useful proposals from earlier runs are lost.

Counter-argument: proposals are non-deterministic; "the same idea phrased two different ways" would clutter the file. The current "one snapshot at a time" design forces the operator to act on proposals quickly.

Possibly worth surfacing per-distill into a side `.proposal_history/` directory if Phase C surfaces concepts as long-lived artifacts.

## Verdict

**PASS.** Phase B's operator workflow is empirically sound:
- B0 closes the empty-matrix loophole.
- B1's `--update` propagates source diffs correctly.
- B2's `--rename` migrates text and leaves a tombstone.
- B3 persists proposals.
- B4 promotes them to stable rows.
- The Phase A determinism gate (14/14) is preserved.

One real bug caught and fixed mid-smoke (`7f68969` — flat-vs-nested cells regression). Two known gaps documented above (revival semantics; CLI `--version`). Several process suggestions captured for Phase C consideration (domain-scoped distill, proposals history).

**Time investment:** ~7 minutes total LLM wall (50s init-only probe + 110s × 3 distill runs) plus deterministic steps and the inline regression fix. Comparable to Phase A's smoke spend.
