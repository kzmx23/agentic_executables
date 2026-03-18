---
title: Agent Track
outline: deep
---

# Agent Track

Use this path if you are integrating AE into an AI agent runtime or MCP-capable client.

## Prerequisites

- Access to CLI execution environment
- Ability to parse structured command output
- Optional: MCP-compatible client

## Step 1: Discover machine-oriented docs

- Read `/llms.txt` for indexed doc entry points.
- Read `/llms-full.txt` for consolidated guidance.

## Step 2: Validate executable contract

Run:

```bash
ae definition
ae verify --input verify.json
```

Expected result:

- Stable envelope structure.
- Deterministic error codes on failure paths.

## Step 3: Execute one agent flow

```bash
ae instructions --context project --action use
```

Then retrieve one registry action:

```bash
ae registry get --library-id python_requests --action use --out ./ae_use
```

## Step 3.5: Use knowledge extraction

Initialize hub and extract domain knowledge for context-aware operations:

```bash
ae hub init
ae know build --url https://modelcontextprotocol.io/llms-full.txt --name mcp
ae generate --library-id dart_mcp --library-root . --know mcp --engine template --dry-run
```

The `--know` flag enriches generation with extracted domain knowledge.

## Step 4: MCP integration

Use the MCP adapter docs in [MCP integration](/mcp/) and keep tool payloads typed.

<div class="success-box">
  First-success complete when your agent can discover docs, execute one command, and recover from one simulated error with documented code-based handling.
</div>
