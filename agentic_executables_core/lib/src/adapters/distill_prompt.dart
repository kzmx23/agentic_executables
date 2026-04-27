/// Shared prompt header for AE distillation tasks. Caller appends the
/// task JSON inside a fenced ```json ... ``` block.
///
/// All three distillation executors (claude_code, byok_llm, codex_exec)
/// MUST use this constant so the LLM gets identical id-stability rules
/// regardless of which backend dispatches the task. See
/// docs/superpowers/specs/2026-04-27-canonical-id-stability-design.md Q7.
const String distillPromptHeader = '''
You are running an AE distillation task. Return ONLY a JSON object that matches schema_out (`ae.canonical.draft.v1`). Do not wrap in prose; if you must, place the JSON in a single ```json fenced code block. No commentary outside the JSON.

ID STABILITY RULES (mandatory):
1. Every feature row you emit MUST have an `id` that already appears in the input task's `matrix_seed_rows`. You are enriching existing rows, not inventing new ones.
2. If you encounter a cross-cutting invariant that does not correspond to any seeded id (e.g. "all commands write a JSON envelope"), DO NOT create a feature row for it. Instead, append it to a top-level `proposed_concepts` array on your response, with shape:
   `{ "name": "<short-kebab-name>", "spec": "...", "invariant": "...", "rationale": "why this is cross-cutting, not a symbol" }`
3. If a seeded row is missing in the input but you believe a new symbol exists in the source artifact, DO NOT invent its id. Surface it as `proposed_concepts` with rationale "missing-from-scaffold; rerun ae canonical scaffold --update".

Schema reminder: the response object has top-level keys `schema`, `concept_id`, `concept_version`, `index_md`, `matrix`, optional `patterns_md`, optional `proposed_concepts`.

Response shape (return EXACTLY this structure, schema strings are literal):

```json
{
  "schema": "ae.canonical.draft.v1",
  "concept_id": "<from input.concept_id>",
  "concept_version": "<from input.concept_version>",
  "index_md": "<your enriched index markdown>",
  "matrix": {
    "schema": "ae.canonical_matrix.v1",
    "concept": "<from input.concept_id>",
    "version": "<from input.concept_version>",
    "column_schema": [{"id": "spec", "type": "text"}, {"id": "invariant", "type": "text"}],
    "features": [
      {"id": "<id from matrix_seed_rows>", "cells": {"spec": "...", "invariant": "..."}}
    ]
  },
  "proposed_concepts": [
    {"name": "<kebab-name>", "spec": "...", "invariant": "...", "rationale": "..."}
  ]
}
```

If you have no enrichments to make on a seeded row, omit it from `matrix.features`. If you have no proposals, omit `proposed_concepts` entirely. Both keys can be absent.
''';
