# Agentic Executables MCP (v2)

`agentic_executables_mcp` is an optional thin adapter over `agentic_executables_core`.
The CLI (`agentic_executables_cli`) is the primary AE interface in v2.

## Tool Surface (Hard-Cut v2)

- `ae_definition`
- `ae_instructions`
- `ae_generate`
- `ae_registry`
- `ae_verify`
- `ae_evaluate`

Legacy tool names are removed.

Migration map:

- `get_agentic_executable_definition` -> `ae_definition`
- `get_ae_instructions` -> `ae_instructions`
- `manage_ae_registry` -> `ae_registry`
- `verify_ae_implementation` -> `ae_verify`
- `evaluate_ae_compliance` -> `ae_evaluate`

## Install

```bash
cd agentic_executables_mcp
dart pub get
dart run bin/agentic_executables_mcp_server.dart
```

## Tool Input Notes

- `ae_instructions`: `context_type`, `action`
- `ae_generate`: `library_id`, `library_root`, optional `output_dir`, `engine`, `dry_run`
- `ae_registry`: `operation` + operation-specific fields
- `ae_verify`: typed verification payload (supports JSON-string fields for compatibility)
- `ae_evaluate`: typed evaluation payload (supports JSON-string fields for compatibility)

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

## Design

- No business logic duplication in MCP.
- All validation, registry, generation, and scoring logic comes from the shared core package.
- MCP responses use v2 envelopes (`success`, `data`, `error`, `warnings`, `meta`).

## Testing

```bash
dart test
```

Run integration test only:

```bash
dart test test/integration_test.dart
```
