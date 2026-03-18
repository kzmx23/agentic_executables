---
title: Troubleshooting
outline: deep
---

# Troubleshooting

Prioritize rapid recovery with stable error code mapping.

## Fast recovery loop

1. Capture the returned error code.
2. Identify retryability.
3. Execute documented recovery command.
4. Re-run the original command.

## High-frequency issues

### `invalid_arguments`

- Fix command flags or payload shape.
- Run: `ae <subcommand> --help`

### `registry_fetch_failed`

- Validate network and source availability.
- Re-run same command after transient failure clears.

### `check_mode_changes_detected`

- Indicates drift was found with `--check`.
- Re-run without `--check` to apply writes.

### `write_conflict_no_overwrite`

- `--no-overwrite` blocked writes.
- Re-run with `--backup` or remove `--no-overwrite`.

### `doctor_checks_failed`

- Review failed checks and run `fix_command` from diagnostic output.

### `hub_not_found`

- No hub exists at project or user level.
- Run: `ae hub init`

### `invalid_name`

- Knowledge pack name doesn't match `[a-z][a-z0-9_]*`.
- Use lowercase letters, numbers, and underscores only.

### `already_exists`

- Knowledge pack with that name already exists.
- Use `ae know update --name <name>` to refresh, or choose a different name.

### `know_not_found`

- Referenced knowledge pack doesn't exist in the hub.
- Run: `ae know list` to see available packs.

### `hub_pull_failed`

- Failed to pull from remote registry.
- Check network and remote config in `hub.yaml`.

## Source-of-truth error contract

Use the canonical playbook:

- [AE Error Code Playbook](https://github.com/fluent-meaning-symbiotic/agentic_executables/blob/main/docs/error_code_playbook.md)
