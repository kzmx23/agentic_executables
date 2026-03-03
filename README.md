# Agentic Executables v2

Agentic Executables (AE) v2 is a CLI-first architecture with a shared Dart core and an optional MCP adapter.

## v2 Architecture

1. `agentic_executables_core/`
- Shared typed domain logic (definition, instructions, validation, registry, generation)
- Transport-agnostic services and DTOs

2. `agentic_executables_cli/`
- Primary interface (`ae`)
- JSON-first output (with `--human` opt-in)
- Codex plugin integration with deterministic template fallback
- Provider-agnostic inference injection (`InferenceClient`) for non-Codex implementations
- Skill install/update management

3. `agentic_executables_mcp/`
- Thin MCP v2 adapter over the shared core
- Reserved optional integration surface

## CLI-First Quick Start

```bash
cd agentic_executables_cli
dart pub get
dart run bin/ae.dart definition
```

Example commands:

```bash
ae instructions --context library --action bootstrap
ae generate --library-id dart_provider --library-root . --engine auto
ae registry get --library-id python_requests --action install
ae verify --input verify.json
ae evaluate --input evaluate.json
ae skill install
```

## MCP v2 Tools

- `ae_definition`
- `ae_instructions`
- `ae_generate`
- `ae_registry`
- `ae_verify`
- `ae_evaluate`

Legacy MCP tool names were removed in v2.

Migration map:

- `get_agentic_executable_definition` -> `ae_definition`
- `get_ae_instructions` -> `ae_instructions`
- `manage_ae_registry` -> `ae_registry`
- `verify_ae_implementation` -> `ae_verify`
- `evaluate_ae_compliance` -> `ae_evaluate`

## Repository Layout

- `prompts_framework/` canonical prompt resources
- `skills/ae-cli/` repo-managed CLI skill template
- `ae_use_registry/` demo examples (official registry remains external)
- `docs/inference_provider_guide.md` provider-agnostic inference extension guide + source references

## Testing

```bash
cd agentic_executables_core && dart test
cd ../agentic_executables_cli && dart test
cd ../agentic_executables_mcp && dart test
```

Integration-focused checks:

```bash
cd agentic_executables_cli && dart test test/integration_test.dart
cd ../agentic_executables_mcp && dart test test/integration_test.dart
```

Integration coverage includes:

- CLI end-to-end flow: definition, instructions, generation, verify/evaluate, registry bootstrap/submit, skill install/update
- MCP adapter end-to-end flow: definition, instructions, generation, verify/evaluate, registry bootstrap/submit

## License

MIT
