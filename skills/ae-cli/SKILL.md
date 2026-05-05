<!-- ae-cli-skill-version: 1.1.0 -->
# ae-cli

Use this skill to execute Agentic Executables workflows through the `ae` CLI.

## Why Use This Skill

- Fast and consistent AE operations for both library and project contexts.
- JSON-first command responses that agents can parse reliably.
- Built-in verify/evaluate workflow to gate quality before publishing.

## Quick Decision Flow

1. Need framework capabilities? Run `ae definition`.
2. Need context rules? Run `ae instructions --context <library|project> --action <action>`.
3. Need AE files? Run `ae generate` (or `ae registry get` if already published).
4. Need quality checks? Run `ae verify` then `ae evaluate`.

## Command Cheatsheet

```bash
ae definition
ae instructions --context library --action bootstrap
ae instructions --context project --action install
ae generate --library-id <id> --library-root <path> --engine auto
ae verify --input <verify.json|->
ae evaluate --input <evaluate.json|->
ae registry get --library-id <id> --action <install|uninstall|update|use>
ae registry submit --library-url <url> --library-id <id> --ae-use-files <csv|repeatable>
ae registry bootstrap-local --ae-use-path <path>
ae skill install
ae skill update
```

## Action Recipes

### Library Bootstrap
1. `ae instructions --context library --action bootstrap`
2. `ae generate --library-id <id> --library-root <path> --engine auto`
3. `ae verify --input <verify.json>`
4. `ae evaluate --input <evaluate.json>`
5. Optional publish prep: `ae registry submit ...`

### Project Install
1. `ae instructions --context project --action install`
2. Optional fetch: `ae registry get --library-id <id> --action install`
3. Execute install/config/integration steps from `ae_install.md`
4. Run project-specific validations

### Project Update
1. `ae instructions --context project --action update`
2. Optional fetch: `ae registry get --library-id <id> --action update`
3. Execute migration + rollback-safe steps from `ae_update.md`
4. Re-run verify/evaluate inputs where applicable

### Project Uninstall
1. `ae instructions --context project --action uninstall`
2. Optional fetch: `ae registry get --library-id <id> --action uninstall`
3. Execute cleanup and reversibility checks from `ae_uninstall.md`

### Usage Rules
1. `ae instructions --context project --action use`
2. Optional fetch: `ae registry get --library-id <id> --action use`
3. Apply usage patterns and guardrails from `ae_use.md`

## Operational Notes

- Prefer `--engine auto` for generation in normal environments.
- Force `--engine template` when deterministic fallback is required.
- Treat `verify` as structural quality gate and `evaluate` as scoring gate.
