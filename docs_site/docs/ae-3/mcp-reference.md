---
title: "MCP tools reference"
outline: deep
---

# MCP tools reference

The `agentic_executables_mcp` server exposes AE's surface as MCP tools. Twelve tools ship in 3.0; this page documents each one's purpose, parameters, response envelope, and the most likely error codes you'll see. Schemas come from `agentic_executables_mcp/lib/src/server.dart`.

If you're consuming AE from Claude Code, the [Claude Code plugin](./plugin) auto-wires this server. From any other MCP client, point it at the `agentic_executables_mcp` binary in stdio mode.

## Response envelope

All AE MCP tools return the same envelope shape (omitted from each section to keep things short):

```jsonc
{
  "success": true,
  "data": { /* tool-specific payload */ },
  "error": null
}
```

On failure: `success: false`, `data: null`, and `error: { code: "...", message: "..." }`. Codes are stable identifiers; the table at [Reference](/reference/) (and `docs/error_code_playbook.md` in the repo) is authoritative.

## Hub-aware tools

### `ae_init`

Scan a project for known language manifests and ingest each sub-package as a local artifact. The MCP equivalent of [`ae init`](./cli-reference#ae-init).

| Parameter | Type | Notes |
|---|---|---|
| `root` | string | Project root path (default: cwd). |
| `strict` | bool | Exit non-zero on unhandled subdirectories. |

Common errors: `no_hub`, `unhandled_subdirs`.

### `ae_status`

Project-wide tier-classified gap report. See [Concepts](./) for the four tiers.

| Parameter | Type | Notes |
|---|---|---|
| `root` | string | Project root. |
| `pack` | string | Narrow to one artifact pack (delegates to per-pack verify). |
| `tier` | string | Show only entries at this tier (`1`–`4`). |

Common errors: `no_hub`.

### `ae_sync`

Re-scan source files for artifact packs and report drift (code + intent).

| Parameter | Type | Notes |
|---|---|---|
| `root` | string | Project root. |
| `pack` | string | Sync only the named pack (default: all). |

Common errors: `no_hub`.

### `ae_canonical`

Multiplexed canonical operations.

| Parameter | Type | Notes |
|---|---|---|
| `operation` | string (req) | One of: `init`, `list`, `snapshot`, `diff`, `import`, `distill`. |
| `concept` | string | Concept slug. Required for most operations. |
| `title` | string | Human title (for `init`). |
| `from` | string | `init`-source path (for `import`); from-version (for `diff`). |
| `to` | string | Concept-id alias (for `import`); to-version (for `diff`). |
| `as` | string | Concept id under which to import. |
| `pack` | string | Source artifact pack name (for `distill`). |
| `mode` | string | `upsert` or `refine` (for `distill`). |
| `root` | string | Project root. |

Common errors: `no_hub`, `validation_error`, `artifact_not_found` (distill), `distillation_failed` (distill).

::: tip
The `distill` operation is wired through the adapter; the public input-schema enum on the `ae_canonical` tool currently advertises only `init|list|snapshot|diff|import`, but the adapter accepts and dispatches `distill` correctly. Treat the adapter validator as authoritative.
:::

### `ae_artifact`

Multiplexed artifact operations.

| Parameter | Type | Notes |
|---|---|---|
| `operation` | string (req) | One of: `list`, `verify`, `link`, `upgrade-canonical`. |
| `pack` | string | Pack name (required for `verify`/`link`/`upgrade-canonical`). |
| `canonical` | string | Canonical reference (e.g. `ecs` or `gltf/core@v2`). |
| `to` | string | Target version (for `upgrade-canonical`). |
| `strict` | bool | Fail on Tier 1+2 (for `verify`). |
| `root` | string | Project root. |

Common errors: `no_hub`, `validation_error`.

### `ae_hub`

Hub management: init, status, pull, push.

| Parameter | Type | Notes |
|---|---|---|
| `operation` | string (req) | One of: `init`, `status`, `pull`, `push`. |
| `path` | string | Hub directory path (for `init`). |
| `project` | bool | Initialize in current project (for `init`). |
| `hub_path` | string | Hub path override (for `status`/`pull`/`push`). |
| `remote` | string | Remote name (default `origin`; for `pull`/`push`). |
| `library_id` | string | Specific library to pull. |
| `type` | string | One of `know`, `use`, `packages` (legacy 2.x partitions; pull/push). |

Common errors: `hub_init_failed`, `hub_not_found`, `hub_status_failed`, `hub_pull_failed`, `hub_push_failed`.

## Registry (carry-over)

### `ae_registry`

| Parameter | Type | Notes |
|---|---|---|
| `operation` | string (req) | One of: `submit_to_registry`, `get_from_registry`, `bootstrap_local_registry`. |
| `library_url` | string | For `submit_to_registry`. |
| `library_id` | string | Library id. |
| `ae_use_files` | string | CSV of AE Use file paths. |
| `action` | string | One of `install`, `uninstall`, `update`, `use`. |
| `ae_use_path` | string | For `bootstrap_local_registry`. |

Common errors: `registry_not_found`, `registry_fetch_failed`, `registry_get_failed`, `registry_submit_failed`, `registry_bootstrap_failed`.

## Definition / instructions / generate (carry-over)

### `ae_definition`

Get the AE framework definition. No parameters.

### `ae_instructions`

Retrieve AE instructions for context (library/project) and action (bootstrap/install/uninstall/update/use). Required: `context_type`, `action`. Optional: `know_name`. Common error: `instructions_failed`.

### `ae_generate`

Generate AE files using `auto|template` engine selection (auto resolves to template inside MCP). Required: `library_id`, `library_root`. Optional: `output_dir`, `engine`, `dry_run`, `know_name`. Common errors: `generation_failed`, `engine_unavailable`, `invalid_generation_output`.

## Verify / evaluate (carry-over, typed payloads)

### `ae_verify`

Verify AE implementation using a typed checklist. Required: `context_type`, `action`. Optional: `files_modified`, `checklist_completed`. Legacy string-encoded JSON payloads are rejected. Common error: `verify_failed`.

### `ae_evaluate`

Evaluate AE compliance. Required: `context_type`, `action`. Optional: `files_created`, `sections_present`, plus boolean flags (`validation_steps_exists`, etc.). Legacy string-encoded JSON payloads are rejected. Common error: `evaluate_failed`.

## Tools listed in spec §13 but not yet shipped

The 3.0 design document earmarks two more tools:

- **`ae_doctor`** — preflight checks. Available today only via the [`ae doctor`](./cli-reference#ae-doctor) CLI; not yet exposed as an MCP tool.
- **`ae_package`** — package resolve / validate. Available via [`ae package`](./cli-reference#ae-package) on the CLI; the MCP-tool version is not in the current server registration.

Track [Roadmap](./roadmap) for status on both.

## Where to next

- [CLI reference](./cli-reference) — same operations from a shell.
- [Claude Code plugin](./plugin) — slash commands that pre-fill the most common MCP calls.
