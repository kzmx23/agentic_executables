# AE 3.0 — Architecture overview

> **Status:** AE 3.0 ships a foundation refactor: canonical packs as first-class concept descriptions, artifact packs as language-specific instances, and a tier-classified verify cockpit that highlights gaps between intent and code. This page orients existing docs_site readers; the full sectional rewrite of every section will land in a 3.0.x follow-up.

## What changed

AE 2.x had a single concept — "knowledge packs" — that mixed conceptual intent (the score) with language-specific implementation (the performance). AE 3.0 splits this into two layers:

- **Canonical pack** = the score. Language-agnostic. Lists features with `spec` and `invariant` fields. Lives at `.ae_hub/canonical/<concept>/`.
- **Artifact pack** = the performance. One per source directory + language. Records `kind` (local | external | use), `source` (file SHAs), `references_canonical` (which canonical(s) it implements), and a matrix cells with `impl` (done/partial/missing/...) and `tests` per feature. Lives at `.ae_hub/artifacts/<kind>/<name>/`.

The artifact's matrix is materialized from the canonical's feature set when you `ae artifact link`. Drift between the two — unverified invariants, missing features upstream, partial implementations — surfaces in `ae status` as a tier-classified gap report.

## The four crystallizations

1. **Knowledge is canonical, code is realization.** Same canonical = many performances (Dart, Rust, Kotlin/Swift).
2. **AE composes with the agent rather than competing with it.** Heuristic by default; LLM work delegated to the host agent (Claude Code subagent / Codex exec / BYOK).
3. **Knowledge has two layers: canonical (intent) and artifact (instance).**
4. **Canonical is a token-efficient cognitive map, not exhaustive documentation.** ~10–50 features per pack, ~2–4k tokens; decompose into siblings when bigger.

## New CLI surface

```
ae init                                      # auto-ingest current project (heuristic, no LLM)
ae status [--pack <name>] [--tier <n>]       # tier-classified gap report
ae sync [--pack <name>]                       # re-scan source files; emit drift

ae canonical {init, list, snapshot, diff, import} ...
ae artifact  {list, verify, link, upgrade-canonical} ...
```

Old `ae know *` commands continue to work for backwards compatibility during the 3.0.x transition.

## New MCP tools

`ae_init`, `ae_status`, `ae_sync`, `ae_canonical`, `ae_artifact` — one per CLI command group above.

## Where to look next

- **Design spec:** `docs/superpowers/specs/2026-04-17-ae-3.0-design.md` (this repo) — full design including the data model, three adapter families, and CLI/MCP surface.
- **Phases overview:** `docs/superpowers/plans/2026-04-17-ae-3.0-phases-overview.md` — what each phase does and the roadmap beyond 3.0.
- **Claude Code plugin:** `plugins/claude-code-ae-plugin/` — install + slash commands + distillation skill.
- **Roadmap (3.1 fast-follow + 3.x):** see spec §15.
