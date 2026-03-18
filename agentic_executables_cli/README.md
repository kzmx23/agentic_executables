# ae CLI (v3)

Primary CLI for Agentic Executables. JSON output by default, `--human` for readable text.

## Quick Start

Install:

```bash
curl -fsSL https://raw.githubusercontent.com/fluent-meaning-symbiotic/agentic_executables/main/install.sh | bash
```

Source:

```bash
dart pub get && dart run bin/ae.dart definition
```

## Command Surface

```bash
# Hub
ae hub init [--path <dir>] [--project]
ae hub status [--hub <path>]
ae hub pull [--remote origin] [--library-id <id>] [--type <know|use|packages>]
ae hub push [--remote origin]

# Knowledge
ae know build --url <url> --name <name> [--format auto|llms_txt|html|markdown] [--repo <git-url>]
ae know list [--hub <path>]
ae know show --name <name>
ae know remove --name <name>
ae know update --name <name>
ae know diff --from <name> --to <name>

# Generate and Instructions
ae generate --library-id <id> --library-root <path> [--know <name>] [--engine auto|codex|template] [--dry-run] [--check] [--diff] [--backup] [--no-overwrite]
ae instructions --context <library|project> --action <bootstrap|install|uninstall|update|use> [--know <name>]

# Registry
ae registry get --library-id <id> --action <install|uninstall|update|use> [--out <path>] [--check] [--diff] [--backup] [--no-overwrite]
ae registry submit --library-url <url> --library-id <id> --ae-use-files <csv>
ae registry bootstrap-local --ae-use-path <path>

# Package
ae package resolve --package <id> --target linux --format json
ae package validate --instructions <file-or-json>

# Validate
ae verify --input <json-file|->
ae evaluate --input <json-file|->

# Environment
ae definition
ae doctor [--target <skills-dir>]
ae skill install [--target <dir>] [--name ae-cli] [--upgrade]
ae skill update [--target <dir>] [--name ae-cli]
```

Use contextual help: `ae <subcommand> --help`

## Safe Writes

Flags for `generate` and `registry get --out`:

| Flag | Behavior |
|------|----------|
| `--check` | Detect changes without writing |
| `--diff` | Include unified diff metadata |
| `--backup` | Timestamped backup before overwrite |
| `--no-overwrite` | Block overwrite of existing files |

Per-file statuses are deterministic: `added`, `updated`, `unchanged`, `blocked`.

## Knowledge Pipeline

```bash
ae hub init
ae know build --url https://modelcontextprotocol.io/llms-full.txt --name mcp
ae generate --library-id my_mcp_sdk --library-root . --know mcp
```

The `--know` flag passes domain knowledge to the generation engine for context-aware output.

## Error Codes

See [`../docs/error_code_playbook.md`](../docs/error_code_playbook.md).

## Testing

```bash
dart test
```
