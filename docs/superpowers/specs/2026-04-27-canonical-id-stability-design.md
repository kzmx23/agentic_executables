# Canonical Id Stability — Design FAQ

**Date:** 2026-04-27
**Status:** `proposed` — not yet implemented; resolves Iter 1 dogfood §8 items 1, 3, 4, 9, 10.
**Supersedes (in part):** AE 3.0 spec [§6 (canonical workflow)](./2026-04-17-ae-3.0-design.md) and [§6.5 (executor selection)](./2026-04-17-ae-3.0-design.md) — those sections describe shipped behavior; this design changes it.
**Empirical motivation:** [Iter 1 dogfood report §2 (Q1)](../notes/2026-04-27-ae-3.0-dogfood-iter-1.md), [§3 (Q2)](../notes/2026-04-27-ae-3.0-dogfood-iter-1.md), [§4 (Q3)](../notes/2026-04-27-ae-3.0-dogfood-iter-1.md).

## Status

This design changes how `ae canonical distill` and the surrounding workflow handle feature ids. It does not change the canonical's on-disk schema (`ae.canonical_matrix.v1`); it changes which IDs are allowed to appear there and how they get there.

A separate document, [`plans/2026-04-27-canonical-id-stability-impl.md`](../plans/2026-04-27-canonical-id-stability-impl.md), sequences the implementation as three phases (A: validator + prompt constraint; B: sync + accept-concept commands; C: FAQ-as-context + reuse-class derivation).

## The headline change

> **Distill never invents ids.** Every id in `matrix.yaml` traces back either to a source symbol (via `ae canonical scaffold`) or to an explicit `accept-concept` operation. Distill enriches text on existing rows; it cannot add new rows directly.

Everything below justifies that one sentence.

---

## Q&A

### Q: What did Iter 1 actually find that motivated this?

A: Two consecutive `ae canonical distill` runs on the same artifact (`agentic_executables_cli`, same binary, no shared state) produced 40 vs 28 features with **zero overlapping ids**. Run A used `ae_cli.<symbol>` namespacing (matching spec §6.7); Run B used semantic categories (`output.* command.* engine.* io.*`). The underlying *concepts* overlapped substantially, but the id sets disjoined completely.

The fault is not "the LLM is non-deterministic" (well-known, accepted). The fault is that the dispatch contract gives the LLM permission to invent ids in the first place. With permission removed, the same LLM non-determinism becomes harmless drift in spec/invariant text — never in ids.

### Q: Why not fix it by adding fields (scope, reuse_class, glossary terms) to the matrix?

A: Adding fields to a non-deterministic extraction multiplies the surface where it can drift. The Q1 runs already disagreed on namespace and granularity; adding `scope` gives them a third axis to disagree on, `reuse_class` a fourth. The fix is constraint, not enrichment.

This is not a rejection of the underlying ideas. Terms belong somewhere (see Q11 — `DESIGN_FAQ.md`). Reuse classification belongs somewhere (see Q9 — derived from the link graph). Just not as more fields the LLM has to fill in per row.

### Q: How do new symbol-derived features get ids?

A: Source-symbol discovery is the deterministic 80% path. Two operations cover it:

1. **Initial seeding.** `ae canonical scaffold --from-artifact <pack>` parses public API symbols and emits one feature per symbol with id `<pack>.<sanitized_symbol>` (already in spec §6.7, shipped 3.1.0).

2. **Reconciling source changes.** A new operation: `ae canonical scaffold --from-artifact <pack> --update --concept <c>` (or, equivalently, `ae canonical sync-symbols --concept <c>`):
   - Parses current source symbols.
   - Compares against `matrix.yaml`.
   - **Adds** rows for symbols present in source, absent from matrix (stub `spec`/`invariant`).
   - **Marks** rows as `removed: true` for symbols absent from source, present in matrix. Does NOT delete — preserves history.
   - **Preserves** all `spec`/`invariant`/`notes` text on existing rows.
   - Emits a summary in the envelope: `added: [...], removed: [...], unchanged: N`.

No LLM involvement in either step. New feature in source → new id in matrix on next sync. Idempotent.

### Q: What about renames? Doesn't `--update` just see them as remove + add?

A: Yes, by default. Strict-by-default rename detection is intentional — silent symbol-rename → silent canonical drift, and downstream consumers (linked artifact packs, spec exports, citations in narrative docs) lose the reference without a signal.

The escape hatch is explicit: `ae canonical scaffold --update --rename <old_id>=<new_id>` (repeatable). Operator confirms each rename. The `removed: true` row is updated to `renamed_to: <new_id>` for traceability; the new row inherits the old row's spec/invariant text.

This matches NeXT/Foundation deprecation discipline: deprecation is announced and traceable, not silent.

### Q: How do new concept-derived features (cross-cutting invariants, not tied to a symbol) get ids?

A: Through a **proposal-then-accept** loop. Distill is allowed to *propose* concept-features but never to write them directly into the matrix.

When `ae canonical distill` runs, the response envelope gains a new field:

```json
{
  "success": true,
  "command": "canonical distill",
  "data": {
    "concept": "ae_cli",
    "feature_count_received": 28,
    "feature_count_after_merge": 28,
    "proposed_concepts": [
      {
        "name": "json-envelope-shape",
        "spec": "Every command writes a JSON object with `success`, `data`, `meta` keys.",
        "invariant": "`success` is a boolean present on every response.",
        "rationale": "Cross-cutting; not tied to any single symbol; shared contract across all dispatchable commands."
      },
      ...
    ]
  }
}
```

`proposed_concepts` is a sibling of the matrix updates — *not* matrix rows. Operator reviews and selects one to promote:

```bash
ae canonical accept-concept --concept ae_cli \
                            --id output.json_envelope \
                            --from-proposal json-envelope-shape
```

The operator chooses the id at acceptance time. **One chance, then it's stable forever** — the id is locked into the matrix and survives all future distill runs (per Q3 preservation). If the operator picks a bad id, they can `ae canonical scaffold --update --rename` later, but the rename is explicit.

### Q: Why proposal-then-accept instead of letting distill write directly?

A: Two reasons that compound:

1. **Concept ids are load-bearing.** Cross-cutting invariants like "json envelope shape" are referenced from narrative docs, spec exports, downstream artifact packs, and (eventually) library extraction. They need to be stable across the pack's lifetime. An LLM that re-rolls them every distill run breaks every reference.

2. **Concepts are rare and high-value.** Iter 1's `agentic_executables_cli` had ~30 features; perhaps 5–7 are true cross-cutting invariants. The friction of one human review per concept is well-placed: it's exactly the kind of architectural decision a human should make, and it happens once per concept.

The alternative — letting distill write concepts directly — has been tested empirically (Iter 1) and produces the Q1 drift. So we're not choosing between "proposal-then-accept" and "no friction"; we're choosing between "proposal-then-accept" and "broken canonicals."

### Q: What's the prompt-side enforcement?

A: One sentence added to the distill dispatch prompt:

> Distill MUST NOT emit a feature row whose `id` is not already present in the matrix. New cross-cutting invariants belong in `proposed_concepts`, not `features`. New symbol-derived features should be reported in `proposed_concepts` only when their corresponding source symbol does not already have a row — but the preferred response in that case is "no proposal; rerun `ae canonical scaffold --update` first."

Plus a hard validator on the distill response: any feature row whose id is absent from the pre-distill matrix is rejected with `validation_error.code = "id_not_in_matrix"`. The LLM cannot bypass this by emitting the row anyway — the merge step refuses it.

This is the one-sentence fix that closes Q1's root cause. Everything else in this document is supporting structure.

### Q: How is granularity controlled?

A: Granularity is a side effect of the symbol-vs-concept split, not a separate decision.

- **Symbol-derived features** are at exactly the granularity of public API symbols. One per symbol that crosses the package boundary (per spec §6.7's existing rule). No LLM judgment.
- **Concept-derived features** are at the granularity of "things humans accepted as cross-cutting concepts." Always coarser than symbols; quantified by how many concepts the operator has chosen to accept.

The matrix is a union of these two layers. Q1's two runs disagreed on granularity because the LLM was deciding both layers at once; under the new design the symbol layer is fixed and the concept layer is human-gated, so granularity is reproducible by construction.

### Q: Where does reuse classification (library vs app vs meta) come from?

A: Derived from the artifact-link graph, not declared as a field.

`ae artifact link --pack <p> --canonical <c>` already creates an edge from artifact pack `<p>` to canonical `<c>` (or to a specific feature). Define:

- A canonical feature linked from ≥2 artifact packs across ≥2 different concepts is **de facto reusable** (= `library` candidate).
- A feature linked from exactly 1 pack is **app-specific**.
- A feature with 0 inbound links is **either fresh or stale** — surfaced as Tier 4 in `ae status` already.

This is computable from existing data — no LLM, no field on the matrix row, no per-distill judgment. Add a derived view in `ae status` (e.g. `--reuse-class library`) that filters by the count.

The Foundation/AppKit lesson: reusability is observed, not declared. Don't ship `reuse_class: library` on row creation. Ship the link counter and let the data answer.

### Q: Where do glossary terms live? Why DESIGN_FAQ.md per concept?

A: `canonical/<concept>/DESIGN_FAQ.md` and `canonical/<concept>/DX_FAQ.md` (one or both, optional). Markdown, Q&A-shaped, human-curated.

Format reference: [`/Users/antonio/xs/ecsly/plugins/DESIGN_FAQ.md`](file:///Users/antonio/xs/ecsly/plugins/DESIGN_FAQ.md). The pattern is "Q: why was X chosen? A: rationale + tradeoff." That's strictly richer than a `glossary.yaml` of strings — it carries the *reasoning* alongside the term, including alternatives that were rejected.

When `ae canonical distill` runs, if `DESIGN_FAQ.md` is present in the concept directory, it's loaded into the executor's context before generation. The executor reads "what does Engine mean here?" from the FAQ rather than guessing. This pins the cross-run vocabulary.

It also gives every accepted concept (Q5, the proposal-then-accept loop) a place to record *why* it was accepted as a concept rather than expressed as a symbol. That history is what makes the concept layer durable across maintainers.

### Q: What about the existing canonicals — do they break?

A: No, but they need a migration step. Existing canonicals were produced under the old contract (LLM invents ids freely). To bring them into the new contract:

1. Run `ae canonical scaffold --update --concept <c> --from-artifact <p>` against each canonical's source artifact. New rows get the deterministic source-symbol ids; existing rows whose id matches a source symbol stay; existing rows whose id does NOT match a source symbol get marked `legacy: true` (a new flag distinct from `removed: true`).
2. For each `legacy: true` row, the operator either (a) explicitly accepts it as a concept (gives it a stable id, drops `legacy:`) or (b) deletes it manually.
3. After migration, all rows are either source-symbol-derived or accepted-concept; the new validator can be turned on.

Migration is one-time per existing canonical. It's manual, but mechanical — no LLM involvement. The Iter 1 dogfood produced two test canonicals (`ae_cli`, `ae_core`, `ae_mcp`) which are good migration test fixtures.

### Q: Does this affect the dispatcher / executor selection at all?

A: No. The dispatcher (which executor runs distill) is orthogonal to the id-discovery contract. Iter 1 §5 (Q4) found a separate problem — dispatcher commits to `claude_code` with no `codex` fallback even when the latter is available. That's tracked separately in spec [§15](./2026-04-17-ae-3.0-design.md) and is not in scope here.

### Q: What about `ae spec export` consumers (the Rust parity-check, etc.)?

A: Nothing on the export side changes. `spec_export.v3` already serializes `matrix.yaml` rows as-is. The new contract just means the rows are stable across distill runs, which makes the exports stable across runs — net positive for downstream consumers.

The two new fields (`removed: true`, `renamed_to: <id>`, `legacy: true` during migration) need to be reflected in the export schema. That's a 3.1.x bump on `ae.canonical.v3`, additive only — old consumers ignore unknown keys.

### Q: How do we know this works?

A: Iter 2 dogfood (planned, not written) re-runs Q1 under the new contract:

1. `ae canonical scaffold --from-artifact agentic_executables_cli --concept ae_cli`
2. `ae canonical distill --pack agentic_executables_cli --concept ae_cli`
3. Reset, repeat 1+2.
4. Compare matrices. **Pass condition:** id sets are identical (allowing for `removed:`/`legacy:` diffs from migration). Spec/invariant text may differ — that's accepted LLM drift, harmless because no reference depends on it.

If Iter 2 passes, Q1 is closed. If it fails, the prompt constraint isn't strong enough and we revisit.

### Q: What if distill's `proposed_concepts` are themselves non-deterministic across runs?

A: They will be, and that's fine — proposals are not committed state. The operator accepts the ones they want; non-accepted proposals don't persist. So the canonical only ever absorbs concepts that a human signed off on, and signed-off concepts are stable forever.

The cost is operator review time on the proposal stream. Mitigation: proposals are batched per distill run (10–30 per `agentic_executables_cli`-sized pack, fewer for larger ones per Q2's flat output budget), and most distill runs after the first will produce few new proposals — the corpus of accepted concepts grows slowly toward saturation.

---

## Specification (formal contract changes)

These are the concrete changes that an implementation plan needs to deliver. Order matches the dependency graph — earlier items don't depend on later ones.

1. **Validator (Phase A).** Reject distill responses whose feature rows include any id not in the pre-distill matrix. Error code `id_not_in_matrix`, returned via `mergeDistillation` in core.
2. **Distill prompt (Phase A).** Add the constraint sentence (Q7). Add a `proposed_concepts` field to the expected response shape.
3. **Distill envelope (Phase A).** Pass `proposed_concepts` through `DistillationResult` → CLI/MCP envelopes verbatim. No matrix mutation.
4. **`ae canonical scaffold --update` (Phase B).** New mode of existing command. Performs symbol diff, adds new rows, marks removed, preserves text. Emits summary in envelope.
5. **`ae canonical scaffold --rename` flag (Phase B).** Repeatable. Maps old → new id; preserves text; updates `removed:` rows to `renamed_to:`.
6. **`ae canonical accept-concept` (Phase B).** New CLI command + MCP operation. Promotes a proposed concept to a matrix row at an operator-chosen id. Required arg: `--id`. Optional arg: `--from-proposal <name>` (selects which proposal in the most-recent distill output, looked up via a small persistent state file `.ae_hub/canonical/<concept>/.last_proposals.json`).
7. **DESIGN_FAQ.md / DX_FAQ.md context loader (Phase C).** Distill loads `canonical/<concept>/DESIGN_FAQ.md` and `DX_FAQ.md` if present and includes them in the executor's input context.
8. **Reuse-class derivation (Phase C).** New flag `ae status --reuse-class library|app|orphan` filtering by inbound link count. No matrix changes; pure query.
9. **Migration helper (Phase C).** `ae canonical scaffold --update --migrate` flag: marks rows with no symbol match as `legacy: true` instead of skipping them. One-time use per existing canonical.

The implementation plan ([`plans/2026-04-27-canonical-id-stability-impl.md`](../plans/2026-04-27-canonical-id-stability-impl.md)) sequences these as Phase A (1–3), Phase B (4–6), Phase C (7–9), with each phase shippable on its own.
