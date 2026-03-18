---
title: Knowledge Extraction
outline: deep
---

# Knowledge Extraction

`ae know` extracts domain knowledge from any source — specs, docs, repos, APIs — and stores it in the hub. Use it to generate instructions for libraries, apps, games, servers, or any implementation.

## How knowledge flows

```text
                    ┌→ Implement features directly (read and code)
ae know build ──────┤
                    └→ ae generate --know ──┬→ Integrate into project
                                            └→ ae package (optional deploy)
```

**Know** extracts domain knowledge. **Use** turns it into executable instructions. Combine them however your project needs.

### Example flows

**Implement from a spec** — extract glTF knowledge, then build a loader:

```bash
ae know build --url <gltf-spec> --name gltf_2 --format html
ae know show --name gltf_2  # agent reads and implements
```

**Generate lifecycle files** — extract MCP knowledge, then produce ae_use files:

```bash
ae know build --url https://modelcontextprotocol.io/llms-full.txt --name mcp
ae generate --library-id dart_mcp --library-root . --know mcp
```

**Rewrite to another language** — extract existing project knowledge, then reimplement:

```bash
ae know build --repo https://github.com/my-org/my-dart-lib --name my_lib
ae know show --name my_lib  # agent reads and rewrites in Rust
```

## Prerequisites

- Hub initialized: `ae hub init`
- Network access (for URL and repo sources)

## Build a knowledge pack

### From an llms.txt or markdown URL

```bash
ae know build --url https://modelcontextprotocol.io/llms-full.txt --name mcp
```

### From an HTML page (converted via Jina Reader)

```bash
ae know build --url https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html --name gltf_2 --format html
```

### From a git repository

```bash
ae know build --repo https://github.com/anthropics/anthropic-sdk-python --name anthropic_sdk
```

### From a local file

```bash
ae know build --url file:///path/to/spec.md --name my_spec
```

Expected result: knowledge pack stored in hub at `know/{name}/` with `index.md` and `meta.yaml`.

## List knowledge packs

```bash
ae know list
```

Returns all stored packs with metadata (source, token estimate, format).

## Show a pack

```bash
ae know show --name mcp
```

Returns the full distilled content.

## Update a pack (re-fetch from source)

```bash
ae know update --name mcp
```

Re-fetches from the original source. If content hasn't changed, returns `no_op: true`.

## Remove a pack

```bash
ae know remove --name mcp
```

## Compare two packs

```bash
ae know diff --from mcp_v1 --to mcp_v2
```

Returns section-level comparison: added, removed, changed, unchanged.

Use this for migration planning between spec versions.

## Use knowledge in generation

The `--know` flag pipes domain knowledge into AE file generation:

```bash
ae generate --library-id dart_mcp_sdk --library-root . --know mcp
```

The inference engine uses the knowledge to produce domain-aware install, uninstall, update, and use instructions.

Also works with instructions:

```bash
ae instructions --context library --action bootstrap --know mcp
```

## Knowledge pack format

```text
hub/know/{name}/
├── index.md      # Distilled content (the core artifact)
├── meta.yaml     # Source URL, format, token estimate, fingerprint
└── patterns.md   # Implementation patterns (optional)
```

### meta.yaml example

```yaml
name: mcp
version: ""
source:
  type: url
  url: "https://modelcontextprotocol.io/llms-full.txt"
  format: llms_txt
distill:
  engine: passthrough
  token_estimate: 349042
fetched_at: "2026-03-18T14:29:30.647953Z"
sha256: "073216e0"
tags: []
```

## Extraction strategies

| Source | Extractor | Format flag | What happens |
|--------|-----------|-------------|-------------|
| llms.txt / markdown URL | Passthrough | `auto` or `llms_txt` | Fetch → normalize → store |
| HTML page | URL Extractor | `html` | Fetch → Jina Reader → markdown → store |
| Git repository | Repo Extractor | auto-detected | Clone → scan README/docs/examples → build index |
| Local file | Passthrough | `auto` or `markdown` | Read → store |

## Common failure modes

### `invalid_name`

Cause: name doesn't match `[a-z][a-z0-9_]*`.

Recovery: use lowercase letters, numbers, and underscores only.

### `already_exists`

Cause: pack with that name exists.

Recovery: use `ae know update` to refresh, or choose a different name.

### `hub_not_found`

Cause: no hub initialized.

Recovery: `ae hub init`

### `unsupported_source`

Cause: no extractor available for the source type.

Recovery: use `--format html` for HTML pages, or use a URL/local source.

## What to do next

- [Generate domain-aware AE files](/use/) with `ae generate --know`
- [Compare specs](/know/) with `ae know diff`
- [Sync with team](/hub/) via `ae hub push`
