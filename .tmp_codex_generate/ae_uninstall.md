# Uninstallation

## Prerequisites
- Confirm target project path: `<PROJECT_ROOT>`.
- If rollback may be needed, store current state:
  - `<PREV_AE_REF>`
  - git commit hash of project before removal.

## Removal Steps
1. Move to project root:
   ```bash
   cd <PROJECT_ROOT>
   ```
2. Remove global CLI:
   ```bash
   dart pub global deactivate agentic_executables_cli
   ```
3. Remove `agentic_executables_core` entry from `pubspec.yaml` (if added).
4. Re-resolve dependencies:
   ```bash
   dart pub get
   ```

## Cleanup
- Remove AE helper files created during setup:
  - `tool/ae.sh`
  - local AE JSON inputs (example: `verify.json`, `evaluate.json`)
- Remove generated AE docs only if explicitly requested:
  - `ae_install.md`, `ae_uninstall.md`, `ae_update.md`, `ae_use.md`
- Remove CI steps that execute `ae ...` commands.

## Validation
- CLI removed:
  ```bash
  ae definition
  ```
  Expected: command not found (or equivalent failure).
- Dependency removed:
  ```bash
  dart pub deps | rg agentic_executables_core
  ```
  Expected: no match.
- Project still resolves:
  ```bash
  dart pub get
  ```
  Expected: completes without AE-related dependency errors.