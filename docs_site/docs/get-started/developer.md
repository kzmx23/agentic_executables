---
title: Developer Track
outline: deep
---

# Developer Track

Use this path if you want speed: install, verify, and run one practical generation/retrieval flow.

## Prerequisites

- macOS or Linux terminal access
- `curl`

## Step 1: Install

```bash
curl -fsSL https://raw.githubusercontent.com/fluent-meaning-symbiotic/agentic_executables/main/install.sh | bash
```

## Step 2: Verify CLI is healthy

```bash
ae definition
ae doctor
```

Expected result:

- `ae definition` returns AE version definition metadata.
- `ae doctor` returns `overall_status: pass` or actionable checks.

## Step 3: Run one useful workflow

Registry pull example:

```bash
ae registry get --library-id python_requests --action install --out ./ae_use
```

Generation example:

```bash
ae generate --library-id dart_provider --library-root . --engine template --check --diff
```

## Step 4: Set up local hub and extract knowledge

```bash
ae hub init
ae know build --url https://modelcontextprotocol.io/llms-full.txt --name mcp
ae know list
```

This creates a local knowledge hub and extracts the MCP protocol spec for later use in generation.

<div class="success-box">
  First-success complete when install + verification pass and one workflow command returns a deterministic result.
</div>

## Next actions

- Use [Install and verify](/install/) for shell/OS-specific fixes.
- Continue with [First workflows](/use/).
