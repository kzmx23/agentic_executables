---
title: "CLI reference"
outline: deep
---

# CLI reference

Every command in the AE 3.0 surface, organized by topic. Synopses come straight from `agentic_executables_cli/lib/src/cli.dart`; if the spec and the code disagree, the code wins (see [Surprises](./roadmap#surprises) on the Roadmap page for the running list).

All commands accept `--human` for readable output (default is JSON envelope) and `-h` / `--help` for command-specific help.

## Commands at a glance

| Command | Purpose |
|---|---|
| [`ae init`](#ae-init) | Heuristic-extract every package in a project into artifacts |
| [`ae status`](#ae-status) | Tier-classified gap report |
| [`ae sync`](#ae-sync) | Re-scan source, write `drift.yaml` |
| [`ae canonical init`](#ae-canonical-init) | Stub a new canonical pack with an empty matrix |
| [`ae canonical scaffold`](#ae-canonical-scaffold) | Heuristic seed from one or more artifacts (no LLM) |
| [`ae canonical list`](#ae-canonical-list) | List canonicals in the resolved hubs |
| [`ae canonical snapshot`](#ae-canonical-snapshot) | Freeze a breaking change into `vN/` |
| [`ae canonical diff`](#ae-canonical-diff) | Diff two versions of a canonical |
| [`ae canonical import`](#ae-canonical-import) | Copy a canonical from a path |
| [`ae canonical distill`](#ae-canonical-distill) | Delegate distillation to an executor |
| [`ae artifact list`](#ae-artifact-list) | List artifacts in the project hub |
| [`ae artifact verify`](#ae-artifact-verify) | Tiered verify for one artifact |
| [`ae artifact link`](#ae-artifact-link) | Add a canonical reference; materialize matrix |
| [`ae artifact upgrade-canonical`](#ae-artifact-upgrade-canonical) | Move an artifact to a newer canonical version |
| [`ae hub init`](#ae-hub-init) | Create `.ae_hub/` |
| [`ae hub status`](#ae-hub-status) | Hub config and resolution diagnostics |
| [`ae registry`](#ae-registry) | AE Use registry operations (carry-over) |
| [`ae package`](#ae-package) | Package resolve / validate (carry-over) |
| [`ae doctor`](#ae-doctor) | Preflight checks |
| [`ae definition`](#ae-definition) | Emit AE framework definition |
| [`ae skill`](#ae-skill) | Install / update the AE CLI skill template |
| [`ae spec export`](#ae-spec-export) | Emit `spec_export.v3` JSON for the hub |

## Project-level commands

### `ae init`

```bash
ae init [--root <dir>] [--strict]
```

Walks `--root` (default cwd) for known manifests, dispatches each sub-package to a [HeuristicExtractor](./adapters#heuristicextractor), and writes one artifact pack per package under `.ae_hub/artifacts/local/`. The hub must exist at `<root>/.ae_hub`; bootstrap with [`ae hub init`](#ae-hub-init) first if it doesn't. Sub-second per package.

Exit codes: `0` on success, non-zero with `unhandled_subdirs` if `--strict` and any sub-directory had no matching extractor, non-zero with `no_hub` if `.ae_hub/` is missing.

See [Quick start](./quick-start) for a full session.

### `ae status`

```bash
ae status [--root <dir>] [--pack <name>] [--tier <n>]
```

Tier-classified gap report across all artifacts, walking the `requires:` graph for Tier 2 downstream-count sorting. `--pack` narrows to a single artifact (delegates to a single-pack verify). `--tier 1..4` shows only the named tier.

Exit codes: `0` on success. Non-zero envelope on hub-resolution failures.

See [Concepts](./) for the four tiers and [Walkthroughs → Multi-language monorepo](./walkthroughs#multi-language-monorepo) for sample output.

### `ae sync`

```bash
ae sync [--root <dir>] [--pack <name>] [--prune]
```

Re-scans source files for each artifact (or just `--pack`). Updates `meta.yaml.files[].sha256`, writes `drift.yaml` with added / modified / removed files. No LLM. No network.

`--prune` (spec §6.2) removes artifact packs whose `meta.source.path` no longer exists on disk — useful after deleting a sub-package. Pruned pack names are surfaced in the envelope under `pruned: [...]`.

## Canonical commands

### `ae canonical init`

```bash
ae canonical init --concept <slug> --title "<title>" [--root <dir>]
```

Scaffolds `canonical/<concept>/` with `meta.yaml`, `matrix.yaml` (empty `features:`), and `index.md`. You edit by hand. Use `<project>/<concept>` slugs for project-private canonicals; bare slugs for canonicals you'd publish.

### `ae canonical scaffold`

```bash
ae canonical scaffold --concept <slug> --title "<title>"
                      --from-artifact <pack> [--from-artifact <pack2> ...]
                      [--overwrite] [--root <dir>]
```

Heuristic seed (no LLM) of a draft canonical pack from one or more artifact packs (spec §6.7). Parses each artifact's `## Public API` section in `index.md` and emits one feature row per detected symbol with stub `spec`/`invariant` cells the user fills in. The draft is the starting line of the editing pass — run `ae canonical distill` against an artifact later for an LLM-assisted enrichment.

Feature ids are namespaced as `<artifact_pack>.<sanitized_symbol>`: camelCase becomes snake_case, non-id characters collapse to underscores, and the first occurrence wins on collision across artifacts. The pack's `meta.yaml.provenance.authored = scaffolded` distinguishes it from `hand` (init) and `distilled_from_artifact` (distill).

Exit codes: `0` on success, non-zero with `canonical_exists` if a pack already lives at `--concept` and `--overwrite` was not passed, `artifact_not_found` if any `--from-artifact` is unknown.

### `ae canonical list`

```bash
ae canonical list [--root <dir>]
```

Lists every canonical visible from this project — project hub first, user hub second. Useful when you can't remember whether a canonical lives in `~/.ae_hub/` or here.

### `ae canonical snapshot`

```bash
ae canonical snapshot --concept <slug> [--root <dir>]
```

Freezes the current live canonical into `canonical/<concept>/v<n>/` and bumps `meta.yaml.version`. Run only when you're introducing a breaking change. See [Authoring canonicals → Living vs snapshot](./authoring-canonicals#living-vs-snapshot).

### `ae canonical diff`

```bash
ae canonical diff --concept <slug> --from <ver> --to <ver> [--root <dir>]
```

Shows the diff between two versions (e.g. `--from v1 --to current`). Used during snapshot review and `upgrade-canonical` planning.

### `ae canonical import`

```bash
ae canonical import --from <path> --as <concept-id> [--root <dir>]
```

Copies a canonical directory from `<path>` (e.g. a package's `.ae_hub/canonical/<concept>/`) into the target hub. The 3.0 path for package-shipped canonicals until auto-discovery lands.

### `ae canonical distill`

```bash
ae canonical distill --pack <artifact> --concept <slug>
                     [--mode upsert|refine] [--root <dir>]
```

Builds a `DistillationTask` from the artifact, dispatches to the matched [DistillationExecutor](./adapters#distillationexecutor), validates the response against `ae.canonical.draft.v1`, and merges into the canonical. `--mode upsert` creates a fresh canonical (default); `--mode refine` seeds the task from an existing canonical for incremental work.

Exit codes: `0` on success, non-zero with `artifact_not_found` if `--pack` is unknown, `distillation_failed` if no executor can run or all attempts failed.

## Artifact commands

### `ae artifact list`

```bash
ae artifact list [--root <dir>]
```

Lists artifacts under `.ae_hub/artifacts/{local,external,use}/`.

### `ae artifact verify`

```bash
ae artifact verify --pack <name> [--strict] [--root <dir>]
```

Tier-classified verify for one artifact. `--strict` exits non-zero on any Tier 1+2 finding (not in `drift.yaml.accepted:`). Use in CI.

### `ae artifact link`

```bash
ae artifact link --pack <name> --canonical <ref>[@<version>] [--root <dir>]
```

Adds the canonical to the artifact's `references_canonical:` list. Bare ref (`ecs`) is live; `@v2` locks to a snapshot. After link, run [`ae sync`](#ae-sync) to materialize matrix rows for the new canonical's features.

### `ae artifact upgrade-canonical`

```bash
ae artifact upgrade-canonical --pack <name> --canonical <slug>
                              --to <version> [--root <dir>]
```

Moves an artifact's reference from one canonical version to another. Renames preserved cells by feature ID, adds new rows, surfaces removed/changed invariants in `drift.yaml`.

## Hub commands

### `ae hub init`

```bash
ae hub init [--project] [--path <dir>]
```

Creates `.ae_hub/` with a starter `hub.yaml`. `--project` initializes in the current project root; `--path` specifies an absolute path (e.g. for the user hub `~/.ae_hub`).

### `ae hub status`

```bash
ae hub status [--hub <path>]
```

Prints hub config, resolution chain, and counts of canonicals/artifacts. The diagnostic for "why isn't AE seeing my canonical?".

`ae hub pull` and `ae hub push` are carry-over from 2.x and operate on the legacy `know/`, `use/`, `packages/` partitions; they do not yet understand 3.0 canonical/artifact layout.

## Registry / package / use (carry-over)

### `ae registry`

```bash
ae registry get        --library-id <id> --action install|uninstall|update|use [--out <path>]
ae registry submit     --library-url <url> --library-id <id> --ae-use-files <csv>
ae registry bootstrap-local --ae-use-path <path>
```

Carry-over from AE 2.x. The AE Use registry (install / uninstall / update instructions for libraries) is unchanged in 3.0.

### `ae package`

```bash
ae package resolve  --package <id> [--target <t>] [--format json]
ae package validate --instructions <file|->
```

Carry-over. Resolves a package version from a manifest; validates an instruction file payload. Does not touch the hub.

The `ae use install/uninstall/update` triplet listed in spec §12 is **not surfaced in the 3.0 CLI**; the existing `ae registry get --action <…>` covers the same flow today.

## System commands

### `ae doctor`

```bash
ae doctor [--target <skills-dir>]
```

Preflight checks. Returns structured check data; non-zero exit when critical checks fail (`failure_code: doctor_checks_failed`).

### `ae definition`

```bash
ae definition
```

Emits the AE framework definition (used by hosts to discover AE's capabilities).

### `ae skill`

```bash
ae skill install [--target <dir>] [--name <slug>] [--upgrade] [--template-path <path>]
ae skill update  [--target <dir>] [--name <slug>] [--template-path <path>]
```

Installs or updates the `ae-cli` skill template into a host's skills directory.

### `ae spec export`

```bash
ae spec export --out <dir> [--hub <path>] [--root <dir>] [--locale <code>]
```

Emits `spec_export.v3` for the hub: `spec_index.json`, one `canonical_<slug>.json` per canonical, one `artifact_<name>.json` per artifact. Drives the Rust parity-check at `experiments/ae_rust_contract/` — the first non-Dart canonical consumer (per spec §9.5).

`ae mcp` (run AE's MCP server in stdio mode) is shipped as the separate `agentic_executables_mcp` binary, not as a subcommand on the `ae` CLI. See [MCP tools reference](./mcp-reference) for the tool surface it exposes.

## Where to next

- [MCP tools reference](./mcp-reference) — the same operations behind ten MCP tools.
- [Walkthroughs](./walkthroughs) — these commands stitched into real flows.
