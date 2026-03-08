# Agentic Executables v3

Agentic Executables (AE) turns library operations into executable instructions that humans and AI agents can run the same way.

## 30-Second Summary

- AE standardizes library workflows into 4 files: `ae_install.md`, `ae_uninstall.md`, `ae_update.md`, `ae_use.md`.
- v3 is a hard-cut release with CLI-first automation (`ae`), typed shared core logic, and MCP parity.
- `ae doctor` adds trust-focused preflight checks.
- CLI generation and registry writes now support safe-write controls: `--check`, `--diff`, `--backup`, `--no-overwrite`.
- MCP `ae_generate` supports `auto|template` only (`auto` resolves to template in MCP).

## Why This Matters

Without AE, library setup and maintenance usually depends on ad-hoc README interpretation.

With AE:
- humans get repeatable, reviewable runbooks.
- agents get structured, deterministic instructions.
- teams get lower integration drift and safer rollback paths.

## Architecture

| Package | Role | Audience |
| --- | --- | --- |
| `agentic_executables_core/` | Shared typed business logic | Integrators, adapter authors |
| `agentic_executables_cli/` | Primary JSON-first interface (`ae`) | Humans and agents |
| `agentic_executables_mcp/` | Optional MCP v3 thin adapter | MCP client integrations |

## Quick Start (Installer First)

Install prebuilt binaries from GitHub Releases:

```bash
curl -fsSL https://raw.githubusercontent.com/fluent-meaning-symbiotic/agentic_executables/main/install.sh | bash
```

Source fallback:

```bash
cd agentic_executables_cli
dart pub get
dart run bin/ae.dart definition
```

## Core Commands

```bash
ae definition
ae doctor
ae instructions --context library --action bootstrap
ae generate --library-id dart_provider --library-root . --engine auto
ae generate --library-id dart_provider --library-root . --check --diff
ae registry get --library-id python_requests --action install --out ./ae_use
ae verify --input verify.json
ae evaluate --input evaluate.json
ae skill install
ae skill install --upgrade
```

## MCP v3 Tools

- `ae_definition`
- `ae_instructions`
- `ae_generate`
- `ae_registry`
- `ae_verify`
- `ae_evaluate`

## Contracts

- Error codes: [`docs/error_code_playbook.md`](docs/error_code_playbook.md)
- Installer: [`install.sh`](install.sh)

## Repository Layout

- `prompts_framework/`: canonical framework prompts.
- `skills/ae-cli/`: canonical skill template source.
- `ae_use_registry/`: demo samples (official registry is external).
- `docs/inference_provider_guide.md`: implement non-Codex generation backends.

## Testing

```bash
cd agentic_executables_core && dart test
cd ../agentic_executables_cli && dart test
cd ../agentic_executables_mcp && dart test
```

## License

MIT
