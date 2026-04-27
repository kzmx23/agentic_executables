---
title: "Adapters"
outline: deep
---

# Adapters

AE 3.0 is ports-and-adapters all the way down. Three independent adapter families do the work; everything else is composition. Each axis is independently extensible — adding a new language extractor doesn't touch sources or distillation, and vice versa. This page is the developer-facing entry point that the spec earmarked for `docs/extending.md`.

If you want to know what AE 3.0 ships out of the box vs. what's roadmapped, this is the page. If you want to write a new adapter for, say, JS/TS or Python, the interfaces below are the contract.

## KnowledgeSource — how raw content gets in

The first family handles "where does the content come from?" — a local directory, a URL, a PDF, a git clone. It's the carry-over from AE 2.x, lightly extended for 3.0.

```dart
abstract interface class KnowledgeSource {
  bool canHandle(KnowSourceSpec spec);
  Future<RawContent> fetch(KnowSourceSpec spec);
}
```

3.0 adapters:

- **`passthrough_source`** — local filesystem path; no transformation.
- **`url_html_source`** — fetch a URL, strip to readable HTML.
- **`pdf_source`** — extract text from a PDF.
- **`git_clone_source`** — shallow clone a git URL into a temp directory and treat as local.

These feed both `HeuristicExtractor` (see below; it expects a local directory) and the canonical-import path. Adding a new source — say, a Notion page — means writing one class that implements the interface and registering it in the dispatcher.

## HeuristicExtractor — language-aware structural parse, no LLM

The second family is new in 3.0 and is the reason `ae init` is sub-second. A heuristic extractor takes a directory, parses manifests, walks public symbols, harvests doc-comments, hashes files, and emits a `HeuristicArtifact` skeleton.

```dart
abstract interface class HeuristicExtractor {
  String get languageId;                    // "dart" | "rust" | "kotlin_swift"
  bool canHandle(Directory sourceDir);
  Future<HeuristicArtifact> extract(Directory sourceDir);
}
```

3.0 adapters:

- **`DartHeuristicExtractor`** — deep. Parses `pubspec.yaml` workspaces, walks recursive sub-packages, detects barrel files, parses library directives, enumerates public symbols, harvests dartdoc comments, flags bridge packages (presence of `dart:ffi` / method-channel imports).
- **`RustHeuristicExtractor`** — solid. Reads `Cargo.toml` workspace members, enumerates `pub` items, is feature-flag aware.
- **`KotlinSwiftHeuristicExtractor`** — best-effort. Parses `Package.swift` and `build.gradle.kts` to identify the package; lists Kotlin/Swift class files. No deep semantic parse on day one.

A `HeuristicArtifact` produces:

- `meta.yaml` skeleton — source path, file hashes, language, scanned timestamp.
- `index.md` — package title, README excerpt, parsed exports/public API, dependency list.
- Empty `matrix.yaml` (`features: []`). Rows are added when a canonical is linked.

JS/TS, Python, and Go extractors are roadmapped (see [Roadmap → 3.2/3.x](./roadmap#three-two-three-x)). The interface is stable; if you need one of these now, write it against the contract above.

## DistillationExecutor — hand a task to an agent

The third family is the deliberate boundary between AE and any LLM. AE never owns a model; it builds a `DistillationTask`, picks an executor, and validates the output against a strict JSON schema.

```dart
abstract interface class DistillationExecutor {
  String get executorId;                    // "claude_code" | "codex" | "byok"
  bool canRun();                            // is host available now?
  Future<DistillationOutput> execute(DistillationTask task);
}
```

3.0 adapters:

- **`ClaudeCodeSubagentExecutor`** — detects host (env var / parent process / MCP context); uses Claude Code's Task tool when running inside the agent, or `claude -p` in CI. Zero new API key required when running inside Claude Code.
- **`CodexExecExecutor`** — uses `codex exec` for non-interactive distillation. Same idea, different host.
- **`ByokLlmExecutor`** — direct API call (Anthropic / OpenAI / etc.) using a user-configured key in `hub.yaml`. The fallback for headless / CI / "I don't want to run inside an agent."

The wire format is documented in spec §7. AE → executor sends `ae.distillation.task.v1`; executor → AE returns `ae.canonical.draft.v1`. On schema validation failure, AE retries once with the validation error included as additional context. A second failure fails loudly — no silent partial merge.

Picking an executor: AE prefers the matched host (Claude Code / Codex if detected), falls back to BYOK if configured, and fails with `distillation_failed` (see the [error code playbook](/reference/)) if none can run. See [CLI reference → ae canonical distill](./cli-reference#ae-canonical-distill) for the user-facing flags.

## Storage — split from the 2.x knowledge store

A quieter but real fourth family. The 2.x `file_know_store` is split into:

- **`FileCanonicalStore`** — read/write `canonical/<concept>/`. Knows about snapshot directories.
- **`FileArtifactStore`** — read/write `artifacts/<kind>/<pack>/`. Handles incremental file-hash updates.

These aren't user-facing in 3.0; they exist to make alternate backends (memory store for tests, future Dgraph if it ever becomes worth it — see [Roadmap → Post-3.x](./roadmap#post-3-x)) drop-in replaceable.

## Hub resolver

`HubResolver` walks the project / user / package / remote chain documented in [Hub layout → Resolution order](./hub-layout#resolution-order). 3.0 implements project + user; package and remote are stubbed in the resolver but inert.

## Services

Above the adapters, services are the orchestrators:

- **`CanonicalService`** — init, list, snapshot, diff, import, distill (via executor).
- **`ArtifactService`** — ingest (calls heuristic extractor), sync (incremental re-scan), verify, link, upgrade-canonical, materialize.
- **`DriftService`** — code drift (file-hash diff vs `meta.yaml`); intent drift (canonical invariants without tests).
- **`DistillationService`** — build task, dispatch executor, validate output, merge into canonical.
- **`HubService`** — config, status, resolution.

Each service is a small surface, separately testable, and lands in its own file under `agentic_executables_core/lib/src/services/`. Read the source if you want the precise contract — it's small enough to hold in one head.

## Where to next

- [Authoring canonicals](./authoring-canonicals) — how `DistillationExecutor` is used end-to-end.
- [CLI reference](./cli-reference) — every command and the adapter it triggers.
- [Roadmap](./roadmap) — which adapters are planned for 3.x.
