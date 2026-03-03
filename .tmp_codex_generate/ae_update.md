# Update

## Prerequisites
- Identify current and target refs:
  - `<CURRENT_AE_REF>`
  - `<TARGET_AE_REF>`
- Confirm project path: `<PROJECT_ROOT>`.
- Record rollback point: `<ROLLBACK_GIT_COMMIT>`.

## Migration Steps
1. Move to project root:
   ```bash
   cd <PROJECT_ROOT>
   ```
2. Update global CLI to target ref:
   ```bash
   dart pub global activate --source git <AE_REPO_URL> --git-path agentic_executables_cli --git-ref <TARGET_AE_REF>
   ```
3. If using SDK dependency, update `pubspec.yaml` `ref:` to `<TARGET_AE_REF>` under `agentic_executables_core`.
4. Refresh dependencies:
   ```bash
   dart pub get
   ```
5. Apply command migration to v2 names if needed:
   - `get_agentic_executable_definition` -> `ae_definition`
   - `get_ae_instructions` -> `ae_instructions`
   - `manage_ae_registry` -> `ae_registry`
   - `verify_ae_implementation` -> `ae_verify`
   - `evaluate_ae_compliance` -> `ae_evaluate`

## Rollback
1. Reinstall previous CLI ref:
   ```bash
   dart pub global activate --source git <AE_REPO_URL> --git-path agentic_executables_cli --git-ref <CURRENT_AE_REF>
   ```
2. Restore `pubspec.yaml` `agentic_executables_core` `ref:` to `<CURRENT_AE_REF>`.
3. Re-run:
   ```bash
   dart pub get
   ```
4. If update changed project files unexpectedly, reset to `<ROLLBACK_GIT_COMMIT>` using project VCS policy.

## Validation
- Updated CLI responds:
  ```bash
  ae definition
  ```
  Expected: `success: true` envelope.
- Instructions command still valid:
  ```bash
  ae instructions --context project --action update
  ```
  Expected: returns update document.
- Optional regression command:
  ```bash
  ae verify --input <VERIFY_JSON_PATH>
  ```
  Expected: command executes with valid JSON response.