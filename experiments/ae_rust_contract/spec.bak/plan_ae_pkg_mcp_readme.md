---
locale: en
---

# Implementation plan: ae_pkg_mcp_readme

## Domain knowledge (index)

# agentic_executables_mcp (v3)

Optional MCP adapter for Agentic Executables v3.

`agentic_executables_cli` is the primary interface in v3.
Use MCP when your agent platform requires MCP tool transport.

## Tool Surface

- `ae_definition`
- `ae_instructions`
- `ae_generate`
- `ae_registry`
- `ae_verify`
- `ae_evaluate`

## Hard-Cut v3 MCP Rules

- `ae_generate.engine` supports `auto|template` only.
- MCP `auto` resolves to template execution in MCP.
- `codex` engine is rejected in MCP.
- `ae_verify` and `ae_evaluate` require typed lists/objects/bools.
- Legacy string-encoded JSON payloads are rejected.

## Install and Run

```bash
cd agentic_executables_mcp
dart pub get
dart run bin/agentic_executables_mcp_server.dart
```

## Typed Payload Example (`ae_verify`)

```json
{
  "context_type": "project",
  "action": "install",
  "files_modified": [
    {
      "path": "ae_install.md",
      "loc": 180,
      "sections": ["Setup", "Config", "Integration", "Validation"]
    }
  ],
  "checklist_completed": {
    "modularity": true,
    "contextual_awareness": true,
    "agent_empowerment": true
  }
}
```

## Typed Payload Example (`ae_evaluate`)

```json
{
  "context_type": "project",
  "action": "install",
  "files_created": [
    {"path": "ae_install.md", "loc": 180}
  ],
  "sections_present": ["Setup", "Config", "Integration", "Validation"],
  "validation_steps_exists": true,
  "integration_points_defined": true,
  "reversibility_included": true,
  "has_meta_rules": false
}
```

## Error Codes Contract

See [`../docs/error_code_playbook.md`](../docs/error_code_playbook.md).

## Testing

```bash
dart test
```

