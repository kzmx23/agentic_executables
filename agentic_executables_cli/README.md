# agentic_executables_cli (v3)

Primary CLI interface for Agentic Executables v3.

Binary: `ae`

Default output is JSON (agent-friendly). Use `--human` for readable text.

## Quick Start

Installer-first (recommended):

```bash
curl -fsSL https://raw.githubusercontent.com/fluent-meaning-symbiotic/agentic_executables/main/install.sh | bash
```

Source fallback:

```bash
dart pub get
dart run bin/ae.dart definition
```

## Command Surface

```bash
ae definition
ae doctor [--target <skills-dir>]
ae instructions --context <library|project> --action <bootstrap|install|uninstall|update|use> [--resources-path <path>]
ae verify --input <json-file|->
ae evaluate --input <json-file|->
ae registry get --library-id <id> --action <install|uninstall|update|use> [--out <path>] [--check] [--diff] [--backup] [--no-overwrite]
ae registry submit --library-url <url> --library-id <id> --ae-use-files <csv|repeatable>
ae registry bootstrap-local --ae-use-path <path>
ae generate --library-id <id> --library-root <path> [--output-dir <path>] [--engine auto|codex|template] [--dry-run] [--check] [--diff] [--backup] [--no-overwrite]
ae skill install [--target <skills-dir>] [--name ae-cli] [--upgrade] [--template-path <path>]
ae skill update [--target <skills-dir>] [--name ae-cli] [--template-path <path>]
```

Use contextual help per command:

```bash
ae <subcommand> --help
```

## Hard-Cut v3 Changes

- `ae doctor` added.
- `ae <subcommand> --help` is contextual.
- `ae skill install --force` removed.
- `ae skill install --upgrade` added.
- `ae skill install` is idempotent for identical content (`no_op: true`).
- `ae generate` and `ae registry get --out` share safe-write flags and atomic writes.

## Safe Writes

Supported flags for `generate` and `registry get --out`:

- `--check`: detect changes without writing.
- `--diff`: include unified diff metadata.
- `--backup`: create timestamped backup before overwrite.
- `--no-overwrite`: block overwrite of existing files.

Per-file statuses are deterministic: `added`, `updated`, `unchanged`, `blocked`.

## Skill Install Semantics

- Missing skill: installs.
- Same content: success with `no_op: true`.
- Different content without `--upgrade`: fails with `skill_upgrade_required`.
- Different content with `--upgrade`: backups old directory and replaces template.

## Preflight (`ae doctor`)

Checks:
- Codex availability (warning)
- Dart SDK availability (warning)
- Skill target writability (critical)
- Registry reachability (critical)

Critical failures return non-zero exit and `data.failure_code = doctor_checks_failed`.

## Error Codes Contract

See [`../docs/error_code_playbook.md`](../docs/error_code_playbook.md).

## Testing

```bash
dart test
```
