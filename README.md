# Agentic Executables v2

Agentic Executables (AE) turns library operations into executable instructions that humans and AI agents can run the same way.

## 30-Second Summary

- AE standardizes library workflows into 4 files: `ae_install.md`, `ae_uninstall.md`, `ae_update.md`, `ae_use.md`.
- v2 is CLI-first (`ae`), with shared typed core logic and optional MCP adapter.
- Generation supports `auto|codex|template`.
- Codex is optional: you can plug in other inference providers.

## Why This Matters

Without AE, library setup and maintenance usually depends on ad-hoc README interpretation.

With AE:
- humans get repeatable, reviewable runbooks.
- agents get structured, deterministic instructions.
- teams get lower integration drift and safer rollback paths.

## Who Uses AE

### For Humans

- library maintainers: generate and publish AE docs for their package.
- project developers: fetch or execute AE docs to install/update/uninstall reliably.
- platform engineers: enforce consistent integration and validation policy.

### For Agents

- coding agents: bootstrap AE files for libraries.
- maintenance agents: verify/evaluate AE quality before publishing.
- project agents: consume registry AE docs and execute changes safely.

## Real Use Cases

1. Bootstrap AE docs for a new library release.
2. Generate deterministic fallback docs when model tooling is unavailable.
3. Fetch registry docs and apply install/update flows in CI or local automation.
4. Validate AE quality with objective verify/evaluate checks.
5. Distribute a reusable skill so agents can run AE workflows consistently.

## How AE Works

1. Define context and action (`library/project` + `bootstrap/install/uninstall/update/use`).
2. Load canonical framework prompts from `prompts_framework/`.
3. Generate or fetch AE markdown artifacts.
4. Apply workflow in target repository.
5. Verify and evaluate quality gates.
6. Publish or consume via registry.

## Architecture

| Package | Role | Audience |
| --- | --- | --- |
| `agentic_executables_core/` | Shared typed business logic | Integrators, adapter authors |
| `agentic_executables_cli/` | Primary JSON-first interface (`ae`) | Humans and agents |
| `agentic_executables_mcp/` | Optional MCP v2 thin adapter | MCP client integrations |

## Quick Start (CLI)

```bash
cd agentic_executables_cli
dart pub get
dart run bin/ae.dart definition
```

If `ae` is not globally available:

```bash
dart run bin/ae.dart <command> ...
```

Core commands:

```bash
ae instructions --context library --action bootstrap
ae generate --library-id dart_provider --library-root . --engine auto
ae verify --input verify.json
ae evaluate --input evaluate.json
ae registry get --library-id python_requests --action install
ae skill install
```

## Quick Start (Agent Perspective)

1. Call `definition` to discover contexts/actions/tooling.
2. Call `instructions` for the target context/action.
3. Run `generate` (or `registry get`) to obtain AE files.
4. Execute workflow steps from generated/fetched files.
5. Run `verify` then `evaluate` before publishing/merging.

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

- `prompts_framework/`: canonical framework prompts.
- `skills/ae-cli/`: repo-managed skill template.
- `ae_use_registry/`: demo samples (official registry is external).
- `docs/inference_provider_guide.md`: how to implement non-Codex generation backends.

## Testing

```bash
cd agentic_executables_core && dart test
cd ../agentic_executables_cli && dart test
cd ../agentic_executables_mcp && dart test
```

Integration checks:

```bash
cd agentic_executables_cli && dart test test/integration_test.dart
cd ../agentic_executables_mcp && dart test test/integration_test.dart
```

## Docs Index

- Core package: `agentic_executables_core/README.md`
- CLI package: `agentic_executables_cli/README.md`
- MCP adapter: `agentic_executables_mcp/README.md`
- Inference provider extension: `docs/inference_provider_guide.md`

## License

MIT
