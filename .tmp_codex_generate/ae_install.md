# Installation

## Prerequisites
- `dart` SDK installed (`dart --version` works).
- `git` installed.
- Write access to `<PROJECT_ROOT>`.
- Set variables:
  - `<PROJECT_ROOT>`: target Dart/Flutter project path.
  - `<AE_REPO_URL>`: `https://github.com/<owner>/agentic_executables.git`.
  - `<AE_REF>`: tag/commit to pin (example: `v2.0.0`).

## Installation Steps
1. Move to project root:
   ```bash
   cd <PROJECT_ROOT>
   ```
2. Install CLI globally from git:
   ```bash
   dart pub global activate --source git <AE_REPO_URL> --git-path agentic_executables_cli --git-ref <AE_REF>
   ```
3. Ensure pub global bin is on `PATH`:
   ```bash
   export PATH="$PATH:$HOME/.pub-cache/bin"
   ```
4. (Optional, SDK integration) Add `agentic_executables_core` to `pubspec.yaml`:
   ```yaml
   dependencies:
     agentic_executables_core:
       git:
         url: <AE_REPO_URL>
         ref: <AE_REF>
         path: agentic_executables_core
   ```
5. Resolve dependencies:
   ```bash
   dart pub get
   ```

## Configuration
- Set default library id for operations: `<LIBRARY_ID>=dart_agentic_executables`.
- Choose resources path if not default: `<AE_RESOURCES_PATH>=<PROJECT_ROOT>/prompts_framework`.
- Optional wrapper script `tool/ae.sh`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  cd <PROJECT_ROOT>
  ae "$@"
  ```

## Integration
- Add AE checks to CI/local workflow:
  ```bash
  ae definition
  ae instructions --context project --action use
  ```
- For library-author flow in this repo style, integrate generation command:
  ```bash
  ae generate --library-id dart_agentic_executables --library-root <PROJECT_ROOT> --engine auto
  ```

## Validation
- CLI reachable:
  ```bash
  ae definition
  ```
  Expected: JSON with `success: true`.
- Instructions fetch works:
  ```bash
  ae instructions --context project --action install
  ```
  Expected: JSON includes `documents`.
- Optional SDK dependency present:
  ```bash
  dart pub deps | rg agentic_executables_core
  ```
  Expected: one dependency match.