# agentic_executables_mcp (v2)

Optional MCP adapter for Agentic Executables v2.

`agentic_executables_cli` is the primary interface in v2.
Use MCP when your agent platform requires MCP tool transport.

## Why This Exists

- Some agent runtimes can call MCP tools but not local CLI binaries directly.
- This package exposes AE features as MCP tools while delegating all business logic to shared core.
- You get parity with CLI behavior without duplicating domain code.

## Audience

### For Humans

Use this package if you are integrating AE with an MCP-native client (Codex MCP mode, IDE MCP bridges, orchestration tools).

### For Agents

Use these tools when MCP is your available execution channel and you need typed AE operations.

## Tool Surface (Hard-Cut v2)

- `ae_definition`
- `ae_instructions`
- `ae_generate`
- `ae_registry`
- `ae_verify`
- `ae_evaluate`

Legacy names were removed in v2.

Migration map:

- `get_agentic_executable_definition` -> `ae_definition`
- `get_ae_instructions` -> `ae_instructions`
- `manage_ae_registry` -> `ae_registry`
- `verify_ae_implementation` -> `ae_verify`
- `evaluate_ae_compliance` -> `ae_evaluate`

## Install and Run

```bash
cd agentic_executables_mcp
dart pub get
dart run bin/agentic_executables_mcp_server.dart
```

## Tool Input Notes

- `ae_instructions`: `context_type`, `action`
- `ae_generate`: `library_id`, `library_root`, optional `output_dir`, `engine`, `dry_run`
- `ae_registry`: `operation` + operation-specific fields
- `ae_verify`: typed verification payload
- `ae_evaluate`: typed evaluation payload

## Response Envelope

All tools return:

```json
{
  "success": true,
  "data": {},
  "warnings": [],
  "meta": {}
}
```

On failure:

```json
{
  "success": false,
  "data": {},
  "error": {
    "code": "validation_error",
    "message": "..."
  },
  "warnings": [],
  "meta": {}
}
```

## Human vs Agent Flow

1. Human configures MCP server once in client config.
2. Agent calls `ae_definition` to discover capabilities.
3. Agent calls `ae_instructions` or `ae_registry`/`ae_generate` depending on task.
4. Agent validates with `ae_verify` then `ae_evaluate`.

## Design Guarantees

- Thin adapter only: no domain logic duplication.
- Validation, registry, generation, and scoring come from `agentic_executables_core`.
- Envelope semantics stay aligned with v2 contracts.

## Testing

```bash
dart test
```

Integration-only:

```bash
dart test test/integration_test.dart
```
