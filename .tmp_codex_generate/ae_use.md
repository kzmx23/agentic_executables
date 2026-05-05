# Usage

## Prerequisites
- AE CLI installed and on `PATH`.
- Work from `<PROJECT_ROOT>`.
- Default library id for this package: `dart_agentic_executables`.

## Patterns
1. Inspect AE framework contract:
   ```bash
   ae definition
   ae instructions --context library --action bootstrap
   ae instructions --context project --action use
   ```
2. Generate AE files for a Dart library:
   ```bash
   ae generate --library-id <TARGET_LIBRARY_ID> --library-root <LIBRARY_ROOT> --engine auto
   ```
3. Validate generated/edited AE docs:
   ```bash
   ae verify --input <VERIFY_JSON_PATH>
   ae evaluate --input <EVALUATE_JSON_PATH>
   ```
4. Fetch AE docs from registry for project execution:
   ```bash
   ae registry get --library-id <TARGET_LIBRARY_ID> --action install
   ae registry get --library-id <TARGET_LIBRARY_ID> --action use
   ```
5. Manage local Codex skill template:
   ```bash
   ae skill install
   ae skill update
   ```

## Validation
- Every command returns JSON envelope with `success`.
- For `generate`, ensure files exist in output directory:
  - `ae_install.md`
  - `ae_uninstall.md`
  - `ae_update.md`
  - `ae_use.md`
- For `verify`/`evaluate`, ensure required fields are present in input JSON before execution.

## Troubleshooting
- `ae: command not found`: add `~/.pub-cache/bin` to `PATH`.
- Registry fetch fails: verify `<TARGET_LIBRARY_ID>` format is `<language>_<library_name>`.
- Generation fallback behavior: rerun with `--engine template` to bypass Codex dependency.
- JSON input errors: validate syntax with `dart run`/editor JSON linter before running CLI commands.