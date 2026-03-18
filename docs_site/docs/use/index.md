---
title: First Workflows
outline: deep
---

# First Workflows

After install + verify, run one of these workflows.

## 1) Inspect definition

```bash
ae definition
```

When to use:

- Confirm CLI is reachable and working.

## 2) Preflight checks

```bash
ae doctor
```

When to use:

- Validate environment and trust setup before generation or registry operations.

## 3) Generate AE files

```bash
ae generate --library-id dart_provider --library-root . --engine template
```

Safe preview:

```bash
ae generate --library-id dart_provider --library-root . --engine template --check --diff
```

## 4) Pull from registry

```bash
ae registry get --library-id python_requests --action install --out ./ae_use
```

## 5) Validate payloads

```bash
ae verify --input verify.json
ae evaluate --input evaluate.json
```

## 6) Initialize a hub

```bash
ae hub init
```

When to use:

- First time setup for local-first artifact storage.
- Before running `ae know` or `ae hub pull` commands.

## 7) Extract domain knowledge

```bash
ae know build --url https://modelcontextprotocol.io/llms-full.txt --name mcp
```

When to use:

- Before generating AE files for a new domain.
- To capture spec knowledge for the team.

## 8) Generate with domain context

```bash
ae generate --library-id dart_mcp_sdk --library-root . --know mcp
```

When to use:

- When you have domain knowledge stored and want AI-aware generation.

## 9) Compare knowledge versions

```bash
ae know diff --from mcp_v1 --to mcp_v2
```

When to use:

- Migration planning between spec versions.
- Understanding what changed in a domain.

## 10) Sync with remote

```bash
ae hub pull --library-id python_requests
ae hub push
```

When to use:

- Share artifacts with team or pull shared projects locally.

## Recovery standard

On failure:

1. Capture error code.
2. Map code to recovery command.
3. Re-run with corrected input.

Use the contract in `docs/error_code_playbook.md`.
