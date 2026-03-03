# Usage

## Prerequisites
- Complete setup from `ae_install.md`.
- Confirm CLI availability: `ae definition`.
- Set environment: `export AE_LIBRARY_ID=dart_agentic_executables`.

## Core Patterns
1. Inspect framework contract:
   - `ae definition`
   - `ae instructions --context library --action bootstrap`
2. Generate or refresh AE files:
   - `ae generate --library-id dart_agentic_executables --library-root <PROJECT_ROOT> --output-dir <PROJECT_ROOT>/ae_use --engine <auto|template>`
3. Pull registry file for consumers:
   - `ae registry get --library-id dart_agentic_executables --action <install|uninstall|update|use>`
4. Validate authored files:
   - `ae verify --input <PROJECT_ROOT>/verify.json`
   - `ae evaluate --input <PROJECT_ROOT>/evaluate.json`
5. Manage Codex skill:
   - `ae skill install --name ae-cli --target <SKILLS_DIR>`
   - `ae skill update --name ae-cli --target <SKILLS_DIR>`

## Guardrails
- Keep `library_id` exactly `dart_agentic_executables`.
- Keep required filenames unchanged.
- Keep each AE file under 500 LOC.
- Pair every install change with an uninstall reversal.
- Run verification before evaluation on each change set.

## Validation
- `rg --files <PROJECT_ROOT>/ae_use` returns all 4 required files.
- `ae verify --input <PROJECT_ROOT>/verify.json` reports checklist completion.
- `ae evaluate --input <PROJECT_ROOT>/evaluate.json` reports structure and reversibility pass.
- `ae registry get --library-id dart_agentic_executables --action use` returns markdown content.

## Troubleshooting
- `ae: command not found`: reinstall CLI and re-export `PATH`.
- Registry fetch fails: verify `library_id`; use local `<PROJECT_ROOT>/ae_use/*.md` as fallback.
- Verify fails on missing sections: restore required headings and rerun `ae verify`.
- Post-update regressions: execute rollback in `ae_update.md`.
