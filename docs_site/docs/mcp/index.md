---
title: MCP Integration
outline: deep
---

# MCP Integration

## Purpose

Integrate AE through MCP (tools and typed payloads) instead of only the CLI, for editors and agents that speak MCP.

## Prerequisites

- MCP client and AE adapter configured (see [Agent track](/get-started/agent)).

## Summary

Use this page when integrating AE capabilities through MCP rather than direct CLI invocation. AE tools work with any project type — libraries, apps, games, servers, or protocol implementations.

## MCP tools exposed by AE adapter

| Tool | Purpose |
|------|---------|
| `ae_definition` | Framework definition and capability matrix |
| `ae_instructions` | Context-appropriate prompt documents (supports `--know`) |
| `ae_generate` | Generate AE lifecycle files (supports `--know`) |
| `ae_registry` | Fetch/submit to remote registry |
| `ae_verify` | Verify implementation checklist |
| `ae_evaluate` | Evaluate AE compliance |
| `ae_hub` | Hub init, status, pull, push |
| `ae_know` | Build, list, show, remove, update, diff knowledge packs |

## Typed payload discipline

- Use typed object payloads.
- Do not send string-encoded JSON where object payloads are required.
- Validate required fields before call dispatch.

## Recommended integration flow

1. Call definition to verify adapter connectivity.
2. Call instructions for task setup.
3. Execute generation or registry operation.
4. Run verify/evaluate as policy checks.
5. Map any failure code to deterministic recovery.

## Knowledge-aware generation flow

1. Call `ae_hub` with operation `init` to ensure hub exists.
2. Call `ae_know` with operation `build` to extract domain knowledge.
3. Call `ae_generate` with `know_name` to produce domain-aware AE files.
4. Call `ae_verify` to validate generated files.

This flow produces higher-quality AE files because the inference engine has domain context.

## Failure handling

- Treat MCP `tool_failed` as envelope-level fallback.
- Prefer tool-specific codes (`validation_error`, `registry_fetch_failed`, etc.) for targeted recovery behavior.
- Keep retries bounded and idempotent.

## Verify

`ae_definition` returns metadata; follow **Recommended integration flow** with bounded retries and typed payloads.

## If it fails

See **Failure handling** above, then [Troubleshooting](/troubleshooting/).

## Related docs

- [Agent track](/get-started/agent)
- [Troubleshooting](/troubleshooting/)
