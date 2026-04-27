# Changelog

All notable changes to this project are documented in this file.

The format is based on [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.2] - 2026-04-27

### Fixed

- `ae hub init` now always nests the hub under `<resolved>/.ae_hub/` and scaffolds the v3 layout (`canonical/`, `artifacts/{local,external,use}/`) per spec §4.1. `--path X` previously created `know/ packages/ use/ hub.yaml` directly inside `X`, polluting any non-empty target directory. (Iter 0 dogfood bug 1.)
- `ae --help` lists the AE 3.0 dispatchable commands (`init`, `status`, `sync`, `canonical`, `artifact`, `spec export`); they were runnable but invisible at the top level. (Iter 0 dogfood bug 2.)
- `ae canonical distill --help` returns contextual help instead of the generic "No contextual help found" miss path. The `spec` / `spec export` help cases were already wired; help test now asserts the miss path no longer fires for any of them. (Iter 0 dogfood bug 3.)
- `mergeDistillation` now surfaces duplicate-id collisions in the distillation output and emits both `feature_count_received` and `feature_count_after_merge` in the CLI/MCP envelope, with a warnings list when the two diverge. The on-disk matrix.yaml was already self-consistent on dogfood-iter-0; the new instrumentation makes future drift visible. (Iter 0 dogfood bug 4.)
- `mergeDistillation` widens `column_schema` to include any cell keys observed on merged features (first-seen order, type `text`), so `canonical/<concept>/matrix.yaml` is always self-consistent on both first-write and merge paths. Resolves the scaffold-vs-distill mismatch where `[spec, invariant]` schema co-existed with `invocation`/`notes` cells. (Iter 0 dogfood bug 5.)

## [3.0.1] - 2026-04-17

### Added

- `ae spec export` reborn on the v3 schema: emits `spec_index.json` (`spec_export.v3`),
  `canonical_<slug>.json` (`ae.canonical.v3`), and `artifact_<name>.json` (`ae.artifact.v3`)
  per pack in the hub.
- `experiments/ae_rust_contract/` parity-check upgraded to consume the v3 shapes and
  report Tier 1/2 gaps — first non-Dart canonical consumer per spec §9.5.

### Removed (hard cut per spec §9)

- `ae know` command family and the `ae_know` MCP tool; all `know/` hub content, `KnowPack`/`KnowMatrix` models, `FileKnowledgeStore`, `DefaultAeKnowService`, and the `KnowledgeExtractor` port.
- `ae e2e sync-know` (not in the 3.0 CLI surface).
- `--know` option on `ae instructions` and `ae generate` (no longer applicable).

### Notes

- 3.0.0's coexistence promise for `ae know *` is now retired. Run `ae init` to create a fresh 3.0 hub; v2 `.ae_hub/know/` content is safe to delete manually.

## [3.0.0] - 2026-04-17

### Added

- **Canonical packs** as first-class concept descriptions: language-agnostic feature lists with `spec` and `invariant` fields. Stored under `.ae_hub/canonical/<concept>/`.
- **Artifact packs** as language-specific instances: kind (local | external | use), source SHAs, `references_canonical`, materialized matrix with `impl` / `tests` cells. Stored under `.ae_hub/artifacts/<kind>/<name>/`.
- **Heuristic extractors** for Dart (deep), Rust (solid), Kotlin/Swift (best-effort). Detect manifests, hash sources, harvest doc-comments, emit `ArtifactPack` skeletons. No LLM.
- **Distillation executors**: Claude Code subagent, Codex exec, BYOK direct LLM. Pluggable executor selection by host detection. Schema-validated wire format (`ae.distillation.task.v1` in / `ae.canonical.draft.v1` out) with retry-once on failure.
- **Tier-classified verify cockpit** (`ae status`): Tier 1 invariant violations, Tier 2 upstream blockers (sorted by downstream count), Tier 3 partial features, Tier 4 unreferenced canonicals.
- **Drift detection** (both axes): code drift via SHA compare, intent drift via canonical-invariant ↔ artifact-tests=yes check.
- **New CLI commands:** `ae init`, `ae status`, `ae sync`, `ae canonical {init, list, snapshot, diff, import}`, `ae artifact {list, verify, link, upgrade-canonical}`.
- **New MCP tools:** `ae_init`, `ae_status`, `ae_sync`, `ae_canonical`, `ae_artifact`.
- **Hub resolver v3:** project hub → user hub resolution chain for canonicals; project-only for artifacts. Package-hub layer stubbed for 3.x.
- **Claude Code plugin scaffold** at `plugins/claude-code-ae-plugin/`: hook, slash commands (`/ae-status`, `/ae-distill`), distillation skill, MCP auto-wiring.

### Reserved (designed-for, not active in 3.0)

- `HubConfig.canonicalRemotes` field for the future public canonical hub (3.x).
- `resolvePackageHub` stub for auto package-hub discovery (3.x).

### Coexistence

- All AE 2.x `ae know *` commands and the `ae_know` MCP tool continue to work. They will be removed in a future cutover release.

### Known limitations

- The 98 KLOC `cli.dart` monolith is unchanged; structural per-command file split is queued for the cutover release.
- Docs site sectional rewrite is queued for a 3.0.x follow-up. See `docs_site/docs/ae-3-overview.md` for an orientation page.
- `ae canonical distill` is wired in core (Phase 3 + 4A) but not yet surfaced as a CLI/MCP command. The `ae-distill` slash command in the Claude Code plugin documents the manual flow until then.

## [2.0.0] - 2026-03-03

### Added

- New shared package: `agentic_executables_core`
- New CLI-first package: `agentic_executables_cli` (`ae` binary)
- Deterministic template generation engine in core
- Optional Codex execution engine in CLI with `auto|codex|template` mode
- Provider-agnostic inference abstraction for custom non-Codex implementations
- Repo-managed skill template at `skills/ae-cli/SKILL.md`
- CLI commands for `skill install` and `skill update`

### Changed

- Architecture moved to 3-package model: core + CLI + MCP thin adapter
- MCP package moved to v2 contracts and tool names
- CLI is now the primary AE interaction surface

### Removed

- Backward compatibility for old MCP tool contracts

## [1.1.0] - 2025-10-13

- moved registry to separate repository: https://github.com/fluent-meaning-symbiotic/agentic_executables_registry
- `ae_use_registry` folder is now a demo folder

## [1.0.0] - 2025-10-13

### Added

- Initial release.
