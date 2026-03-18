# AE Know — Implementation Roadmap

Reference: [ae_know_design.md](ae_know_design.md)

---

## Phase 0: Hub Foundation

**Goal**: Establish the local-first hub directory convention and resolver.

**Why first**: Every subsequent phase needs a place to read/write artifacts. Without the hub, know packs have no home.

### 0.1 — Core types and config

**Files**:
- `core/models/hub.dart` — `HubConfig`, `HubRemote`, `HubStatus`
- `core/config/ae_core_config.dart` — add hub constants: default paths, directory names

**Types**:
```dart
class HubConfig { remotes, defaults, version }
class HubRemote { url, branch, type }
class HubStatus { path, knowCount, useCount, packageCount, remotes }
```

**LOC estimate**: ~80

### 0.2 — Hub resolver port + file adapter

**Files**:
- `core/ports/hub_resolver.dart` — `HubResolver` interface
- `core/adapters/file_hub_resolver.dart` — filesystem implementation

**Resolution logic**:
1. Check `projectRoot/.ae_hub/` (if projectRoot provided)
2. Check `~/.ae_hub/`
3. Return null if neither exists

**LOC estimate**: ~100

### 0.3 — Hub service + CLI commands

**Files**:
- `core/services/ae_hub_service.dart` — interface
- `core/services/default_ae_hub_service.dart` — implementation
- CLI: `ae hub init`, `ae hub status`

**`ae hub init`** behavior:
1. Create directory structure: `hub.yaml`, `know/`, `use/`, `packages/`
2. Write default `hub.yaml`
3. Return created path

**`ae hub status`** behavior:
1. Resolve hub path
2. Count artifacts in each subdirectory
3. Parse `hub.yaml` for remote config
4. Return summary

**LOC estimate**: ~120 (service) + ~80 (CLI wiring)

### 0.4 — Barrel exports + tests

- Export new types/services/adapters from `agentic_executables_core.dart`
- Unit tests for hub resolver (project > user > none resolution)
- Unit tests for hub init (directory creation, hub.yaml content)

**LOC estimate**: ~100 (tests)

### Phase 0 total: ~480 LOC

---

## Phase 1: Know — Passthrough Extraction

**Goal**: `ae know build --url <url> --name <name>` works end-to-end for llms.txt and markdown URLs.

### 1.1 — Know types

**Files**:
- `core/models/know.dart` — all know models

**Types**:
```dart
enum KnowSourceType { url, repo, local }
enum KnowFormat { llmsTxt, html, markdown, repo }
enum KnowDistillEngine { passthrough, inference }

class KnowSource { type, url, path, format }
class KnowMeta { name, version, source, distill, tags, fetchedAt, sha256 }
class KnowPack { meta, indexContent, patternsContent }

class KnowBuildInput { url, repo, path, name, engine, hubPath }
class KnowBuildOutput { name, meta, filesWritten }
class KnowShowInput { name, hubPath }
class KnowShowOutput { name, meta, content }
class KnowListInput { hubPath }
class KnowListOutput { packs (List<KnowMeta>) }
class KnowRemoveInput { name, hubPath }
class KnowUpdateInput { name, hubPath }
```

**LOC estimate**: ~120

### 1.2 — Knowledge extractor port + passthrough adapter

**Files**:
- `core/ports/know_extractor.dart` — `KnowledgeExtractor` interface
- `core/adapters/passthrough_extractor.dart` — fetch URL, normalize, return as KnowPack

**Passthrough logic**:
1. HTTP GET the URL
2. Detect format from content-type header and URL pattern
3. Normalize whitespace, strip HTML artifacts if any
4. Compute SHA-256 of raw content
5. Estimate token count (~4 chars/token)
6. Return `KnowPack` with `meta` populated

**LOC estimate**: ~90

### 1.3 — Knowledge store port + file adapter

**Files**:
- `core/ports/know_store.dart` — `KnowledgeStore` interface
- `core/adapters/file_know_store.dart` — read/write `ae_hub/know/{name}/`

**File store operations**:
- `save()`: create dir, write `index.md` + `meta.yaml` (+ optional `patterns.md`)
- `load()`: read files, parse meta.yaml, return KnowPack
- `list()`: scan know/ subdirectories, parse each meta.yaml
- `exists()`: check directory + index.md presence
- `remove()`: delete directory

**LOC estimate**: ~110

### 1.4 — Know service

**Files**:
- `core/services/ae_know_service.dart` — interface
- `core/services/default_ae_know_service.dart` — orchestrates extractor + store

**`build()` flow**:
1. Validate input (name format, URL accessibility)
2. Resolve hub path via HubResolver
3. Determine extractor (passthrough for now)
4. Call `extractor.extract(source)`
5. Call `store.save(name, pack)`
6. Return output with files written

**`show()` flow**:
1. Resolve hub path
2. Call `store.load(name)`
3. Return content

**`list()` flow**:
1. Resolve hub path
2. Call `store.list()`

**`remove()` flow**:
1. Resolve hub path
2. Call `store.remove(name)`

**`update()` flow**:
1. Load existing meta → get source URL
2. Re-fetch
3. Compare SHA-256
4. If changed, overwrite; if same, return no_op

**LOC estimate**: ~130

### 1.5 — CLI wiring

**CLI commands**:
```
ae know build --url <url> --name <name> [--hub <path>]
ae know list [--hub <path>]
ae know show --name <name> [--hub <path>]
ae know remove --name <name> [--hub <path>]
ae know update --name <name> [--hub <path>]
```

**Parser additions** in `_buildParser()`:
- `know` command with subcommands: `build`, `list`, `show`, `remove`, `update`

**Handler**: `_handleKnow(command)` → switch on subcommand name → delegate

**LOC estimate**: ~150

### 1.6 — MCP tool

**New tool**: `ae_know` in MCP server with operations: `build`, `list`, `show`, `remove`, `update`

**Adapter method**: `AeMcpAdapter.know()` — parse params, call service, return envelope

**LOC estimate**: ~80

### 1.7 — Tests

- Passthrough extractor: mock HTTP, verify meta population
- File know store: round-trip save/load/list/remove
- Know service: end-to-end with mock extractor + store
- CLI: command parsing, flag validation

**LOC estimate**: ~200

### Phase 1 total: ~880 LOC (across ~12 files, each well under 500 LOC)

---

## Phase 2: Know → Generate Integration

**Goal**: `ae generate --know <name>` produces domain-aware ae_use files.

### 2.1 — Extend GenerateInput

- Add optional `knowName` and `knowContent` fields to `GenerateInput`
- Template engine: ignore know (no change)
- Inference engine: prepend know content to generation prompt

**LOC estimate**: ~40

### 2.2 — Extend CLI generate command

- Add `--know <name>` flag to `ae generate` parser
- In `_handleGenerate()`: resolve know pack from hub, pass content to GenerateInput

**LOC estimate**: ~30

### 2.3 — Extend instructions command

- Add `--know <name>` flag to `ae instructions` parser
- Append `## Domain Context` section to returned instructions when know is provided

**LOC estimate**: ~30

### 2.4 — MCP tool updates

- Add optional `know_name` param to `ae_generate` and `ae_instructions` tools

**LOC estimate**: ~20

### 2.5 — Tests

- Generate with know context: verify inference prompt includes know
- Instructions with know context: verify output includes domain section

**LOC estimate**: ~80

### Phase 2 total: ~200 LOC

---

## Phase 3: Hub Remote Sync

**Goal**: `ae hub pull` / `ae hub push` sync local hub with remote GitHub registry.

### 3.1 — Hub sync service

**Files**:
- `core/services/ae_hub_sync_service.dart` — interface
- `core/services/default_ae_hub_sync_service.dart` — implementation

**`pull()`**: For each artifact type (know/, use/), fetch manifest from remote, diff with local, download missing/updated files.

**`push()`**: Generate commit instructions (similar to `registry submit`) for new/changed local artifacts.

**LOC estimate**: ~180

### 3.2 — CLI commands

```
ae hub pull [--remote origin] [--type know|use|packages|all]
ae hub push [--remote origin]
```

**LOC estimate**: ~60

### 3.3 — Migrate existing registry resolution

- `ae registry get` now checks local hub first, falls back to remote
- `ae registry bootstrap-local` → alias for `ae hub init + ae hub import`

**LOC estimate**: ~80

### 3.4 — Tests

**LOC estimate**: ~120

### Phase 3 total: ~440 LOC

---

## Phase 4: URL Extraction (HTML → Markdown)

**Goal**: `ae know build --url <html-spec-url> --name gltf_2` works for HTML specs.

### 4.1 — URL extractor adapter

**Files**:
- `core/adapters/url_extractor.dart`

**Approach**:
1. Fetch HTML
2. Convert to markdown (use Jina Reader API: `https://r.jina.ai/<url>` or built-in HTML-to-MD)
3. Chunk if > token limit
4. Store as index.md

**LOC estimate**: ~100

### 4.2 — Extractor registry

Chain of responsibility: try each extractor, use first that `canHandle()` returns true.

**LOC estimate**: ~30

### 4.3 — Tests

**LOC estimate**: ~80

### Phase 4 total: ~210 LOC

---

## Phase 5: Know Diff & Migration

**Goal**: `ae know diff --from mcp_v1 --to mcp_v2` produces migration guidance.

### 5.1 — Diff engine

**Files**:
- `core/services/know_diff_service.dart`

**Approach**:
1. Load both know packs
2. Structural diff (section-by-section comparison)
3. Semantic summary (requires inference engine)
4. Output: `KnowDiff { added, removed, changed, migrationNotes }`

**LOC estimate**: ~120

### 5.2 — CLI + MCP

```
ae know diff --from <name> --to <name>
```

**LOC estimate**: ~60

### 5.3 — Tests

**LOC estimate**: ~80

### Phase 5 total: ~260 LOC

---

## Phase 6: Repo Extraction

**Goal**: `ae know build --repo <git-url> --name <name>` extracts knowledge from source repos.

### 6.1 — Repo extractor adapter

**Files**:
- `core/adapters/repo_extractor.dart`

**Approach**:
1. Shallow clone (`git clone --depth 1`)
2. Scan for: README.md, docs/, CHANGELOG.md, examples/, src/ entry points
3. Extract public API surface (language-aware heuristics)
4. Build structured knowledge from discovered artifacts
5. Use inference engine to distill into index.md

**LOC estimate**: ~200

### 6.2 — Tests

**LOC estimate**: ~100

### Phase 6 total: ~300 LOC

---

## Phase Summary

| Phase | Scope | LOC | Depends On | Delivers |
|-------|-------|-----|------------|----------|
| **0** | Hub foundation | ~480 | — | `ae hub init/status`, resolver chain |
| **1** | Know passthrough | ~880 | Phase 0 | `ae know build/list/show/remove/update` for URLs |
| **2** | Know → Generate | ~200 | Phase 1 | `ae generate --know`, `ae instructions --know` |
| **3** | Hub remote sync | ~440 | Phase 0 | `ae hub pull/push`, local-first registry |
| **4** | HTML extraction | ~210 | Phase 1 | HTML spec → know conversion |
| **5** | Know diff | ~260 | Phase 1 | `ae know diff` for migration |
| **6** | Repo extraction | ~300 | Phase 1 | Git repo → know extraction |

**Critical path**: Phase 0 → Phase 1 → Phase 2 (minimum viable pipeline)

**Parallelizable**: Phase 3, 4, 5, 6 are independent after Phase 1.

---

## Order of Implementation

```
Week 1:  Phase 0 (hub foundation)
Week 2:  Phase 1.1–1.4 (know core: types, extractor, store, service)
Week 3:  Phase 1.5–1.7 (know CLI + MCP + tests)
Week 4:  Phase 2 (generate integration) + Phase 3 (hub sync)
Week 5:  Phase 4 (HTML extraction) + Phase 5 (know diff)
Week 6:  Phase 6 (repo extraction) + polish + docs
```

Total new code: ~2,770 LOC across ~25 files, each well under 500 LOC.

---

## Architecture Diagram Update

After implementation, the architecture becomes:

```
Source (URL/repo/local)
        │
        ▼
   ┌─────────┐
   │ ae know  │  ← Extract + distill
   │  build   │
   └────┬─────┘
        │
        ▼
   ┌─────────────────────────────────┐
   │           ae_hub/               │  ← Local-first storage
   │  ┌──────┐ ┌──────┐ ┌────────┐  │
   │  │ know │ │ use  │ │packages│  │
   │  └──┬───┘ └──┬───┘ └───┬────┘  │
   │     │        │         │        │
   └─────┼────────┼─────────┼────────┘
         │        │         │
         ▼        ▼         ▼
    ae generate  ae registry  ae package
    ae instruct. (lifecycle)  (deploy)
         │        │         │
         ▼        ▼         ▼
      ae_use/   ae_use/   ae.v3.
      files     registry  package.v1
```

## File Naming Convention

All new files follow existing patterns:
- Ports: `ae_{concept}_service.dart`, `{concept}_{role}.dart`
- Services: `default_ae_{concept}_service.dart`
- Adapters: `{strategy}_{role}.dart`
- Models: `{concept}.dart`
- Tests: `{concept}_test.dart`
