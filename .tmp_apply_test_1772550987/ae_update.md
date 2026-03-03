# Update

## Prerequisites
- Set working directory: `cd <PROJECT_ROOT>`.
- Record current state: `dart pub global list | rg agentic_executables_cli` and `dart pub deps | rg agentic_executables`.
- Backup AE files: `cp -R <PROJECT_ROOT>/ae_use <PROJECT_ROOT>/ae_use.backup.<DATE_TAG>`.

## Version Scope
- Current version: `<CURRENT_VERSION>`.
- Target version: `<TARGET_VERSION>`.
- Update window: `<MAJOR|MINOR|PATCH>`.
- Breaking changes source: `<CHANGELOG_PATH_OR_URL>`.

## Migration Steps
1. Update CLI: `dart pub global activate agentic_executables_cli <TARGET_VERSION>`.
2. Update embedded dependencies: `dart pub add agentic_executables_core --version <TARGET_CORE_VERSION>`.
3. Update MCP adapter (if used): `dart pub add agentic_executables_mcp --version <TARGET_MCP_VERSION>`.
4. Regenerate AE docs: `ae generate --library-id dart_agentic_executables --library-root <PROJECT_ROOT> --output-dir <PROJECT_ROOT>/ae_use --engine <auto|template>`.
5. Refresh skill: `ae skill update --name ae-cli --target <SKILLS_DIR>`.

## Rollback
1. Restore previous CLI: `dart pub global activate agentic_executables_cli <CURRENT_VERSION>`.
2. Restore previous package versions using saved constraints in `<PROJECT_ROOT>/pubspec.yaml`.
3. Restore AE files backup: `rm -rf <PROJECT_ROOT>/ae_use && mv <PROJECT_ROOT>/ae_use.backup.<DATE_TAG> <PROJECT_ROOT>/ae_use`.
4. Re-run baseline check: `<PROJECT_BASELINE_COMMAND>`.

## Validation
- `ae definition` succeeds after update.
- `ae generate --library-id dart_agentic_executables --library-root <PROJECT_ROOT> --output-dir <PROJECT_ROOT>/ae_use --engine <auto|template> --dry-run` reports 4 files.
- `ae verify --input <PROJECT_ROOT>/verify.json` returns success.
- `ae evaluate --input <PROJECT_ROOT>/evaluate.json` returns pass/warning only (no fail).
