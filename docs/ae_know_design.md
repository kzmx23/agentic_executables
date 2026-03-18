# AE Know — Domain Knowledge Pipeline (Design)

## Problem

AE manages lifecycle (install/uninstall/update/use) but assumes domain knowledge already exists in someone's head. There's no formal way to:
- Capture domain knowledge from specs, docs, repos, or llms.txt
- Store it locally for offline use
- Feed it into generation and instructions
- Share it across projects or teams
- Compare versions for migration

## Architecture: Local-First Hub

### The Hub

A **hub** is a directory with a known structure. It holds three artifact types under one roof:

```
ae_hub/
├── hub.yaml              # Config: remotes, defaults
├── know/                 # Domain knowledge packs
│   ├── mcp/
│   │   ├── index.md      # Distilled knowledge
│   │   └── meta.yaml     # Source, version, hash
│   └── gltf_2/
│       ├── index.md
│       ├── meta.yaml
│       └── patterns.md   # Implementation patterns (optional)
├── use/                  # Lifecycle files (what ae_use_registry/ is today)
│   ├── dart_mcp/
│   │   ├── ae_install.md
│   │   ├── ae_uninstall.md
│   │   ├── ae_update.md
│   │   └── ae_use.md
│   └── python_requests/
│       └── ...
└── packages/             # Lythe package instructions
    └── dev.xs.mcp-gateway/
        └── ae.instructions.json
```

### Resolution Chain

When any command needs an artifact, it resolves through:

```
1. Project hub:  ./.ae_hub/         (project-specific overrides)
2. User hub:     ~/.ae_hub/         (shared across all projects)
3. Remote:       GitHub registry    (fetched on demand, cached to user hub)
```

This mirrors Dart pub cache, npm node_modules, and git remote conventions.

### hub.yaml

```yaml
version: 1
defaults:
  know_dir: know        # default subdirectory names
  use_dir: use
  packages_dir: packages

remotes:
  origin:               # primary remote (for use/ and know/)
    url: https://github.com/fluent-meaning-symbiotic/agentic_executables_registry
    branch: main
    type: github        # github | local | custom
  private:              # optional secondary remote
    url: https://github.com/myorg/ae-hub
    branch: main
    type: github
```

### Local-First Guarantees

1. **Every operation works offline** — remote is never required
2. **Remote is pull-on-demand** — nothing auto-syncs without explicit command
3. **Local always wins** — project hub overrides user hub overrides remote
4. **Explicit push** — sharing requires `ae hub push`
5. **Portable** — a hub directory can be copied, committed, or symlinked

## Know Format

### meta.yaml

```yaml
name: mcp
version: "2025-03-26"          # version of the source, not of this file
source:
  type: url                     # url | repo | local
  url: "https://modelcontextprotocol.io/llms-full.txt"
  fetched_at: "2026-03-18T10:00:00Z"
  sha256: "abc123..."
  format: llms_txt              # llms_txt | html | markdown | repo
distill:
  engine: passthrough           # passthrough | inference
  model: null
  token_estimate: 12400
tags: [protocol, rpc, ai]
```

### index.md

Core distilled artifact. Structure adapts to source type:

```markdown
# {Name}

> One-line summary

## Overview
Core concepts, purpose, architecture.

## Key Concepts
Domain model, vocabulary, relationships.

## Patterns
Typical implementation approaches.

## Constraints
Hard rules, edge cases, gotchas.

## References
- [Full spec](url)
- [Examples](url)
```

Quality gate: if an LLM can implement a correct integration after reading only `index.md`, the distillation succeeded.

## Commands

### Hub Management

```bash
ae hub init [--path <dir>]        # Create hub structure (default: ~/.ae_hub)
ae hub init --project             # Create .ae_hub/ in current project
ae hub status                     # Show hub location, artifact counts, remote config
ae hub push [--remote <name>]     # Push local artifacts to remote
ae hub pull [--remote <name>]     # Pull from remote to local
```

### Know Operations

```bash
ae know build --url <url> --name <name>         # Fetch + distill + store
ae know build --repo <git-url> --name <name>    # Clone + extract + store (phase 2)
ae know build --path <local> --name <name>      # Ingest local file + store

ae know list                                     # List all know packs across hubs
ae know show --name <name>                       # Print index.md contents
ae know remove --name <name>                     # Remove a know pack

ae know diff --from <name> --to <name>           # Compare two know packs (phase 3)
ae know update --name <name>                     # Re-fetch and re-distill from source
```

### Enhanced Existing Commands

```bash
ae generate --library-id <id> --library-root . --know <name>
ae instructions --context library --action bootstrap --know <name>
```

## Extraction Strategies

| Source | Extractor | Phase | Approach |
|--------|-----------|-------|----------|
| llms.txt / llms-full.txt | PassthroughExtractor | 1 | Fetch → normalize → store as index.md |
| Markdown URL | PassthroughExtractor | 1 | Fetch → store as index.md |
| HTML page | UrlExtractor | 2 | Fetch → HTML-to-MD → store |
| Git repository | RepoExtractor | 3 | Clone → analyze README/docs/src → distill |

## Integration Points

### Generation (`ae generate --know <name>`)

The generation engine receives know context alongside existing inputs:

```dart
class GenerateInput {
  // ... existing fields ...
  final String? knowName;    // optional know pack reference
  final String? knowContent; // resolved index.md content
}
```

Template engine: ignores know (can't use freeform context).
Inference engine: prepends know context to the generation prompt.

### Instructions (`ae instructions --know <name>`)

Returns instructions enriched with a `## Domain Context` section containing the know pack's index.md.

### Registry Integration

The existing registry becomes one possible remote for the hub:
- `ae registry get` → resolves through hub chain (local first, then remote)
- `ae registry submit` → unchanged (still generates PR instructions)
- `ae hub pull` → fetches both know/ and use/ from remote

## Core Architecture (Dart)

### New Files

```
agentic_executables_core/lib/src/
  models/
    know.dart               # KnowMeta, KnowPack, KnowBuildInput, KnowBuildOutput, etc.
    hub.dart                # HubConfig, HubStatus, HubRemote
  ports/
    know_extractor.dart     # KnowledgeExtractor interface
    know_store.dart         # KnowledgeStore interface
    hub_resolver.dart       # HubResolver interface
  services/
    ae_know_service.dart    # AeKnowService interface
    default_ae_know_service.dart
    ae_hub_service.dart     # AeHubService interface
    default_ae_hub_service.dart
  adapters/
    passthrough_extractor.dart
    file_know_store.dart
    file_hub_resolver.dart
```

### Port Interfaces

```dart
abstract interface class KnowledgeExtractor {
  bool canHandle(KnowSource source);
  Future<KnowPack> extract(KnowSource source);
}

abstract interface class KnowledgeStore {
  Future<void> save(String name, KnowPack pack);
  Future<KnowPack?> load(String name);
  Future<List<KnowMeta>> list();
  Future<bool> exists(String name);
  Future<void> remove(String name);
}

abstract interface class HubResolver {
  Future<String?> resolveKnow(String name);   // returns path to know pack
  Future<String?> resolveUse(String libraryId, AeAction action);
  Future<HubConfig> loadConfig();
  Future<HubStatus> status();
}
```

### Service Interface

```dart
abstract interface class AeKnowService {
  Future<AeResult<KnowBuildOutput>> build(KnowBuildInput input);
  Future<AeResult<KnowShowOutput>> show(KnowShowInput input);
  AeResult<KnowListOutput> list(KnowListInput input);
  Future<AeResult<void>> remove(KnowRemoveInput input);
  Future<AeResult<KnowBuildOutput>> update(KnowUpdateInput input);
}
```

## Backward Compatibility

- `ae registry get` continues to work exactly as before
- `ae_use_registry/` directory remains valid
- Hub is opt-in: if no `.ae_hub/` or `~/.ae_hub/` exists, everything falls back to current behavior
- `ae hub init` is the explicit opt-in to the hub model

## Migration Path

Existing `ae_use_registry/` can be imported into a hub:

```bash
ae hub init
ae hub import --from ./ae_use_registry --type use
```
