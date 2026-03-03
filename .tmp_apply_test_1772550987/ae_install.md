# Installation

## Prerequisites
- Run `dart --version` and confirm `>=3.8.0`.
- Set working directory: `cd <PROJECT_ROOT>`.
- Choose mode with `<AE_MODE>`: `cli`, `embedded`, or `mcp`.

## Installation Steps
1. Install CLI (recommended): `dart pub global activate agentic_executables_cli <AE_VERSION>`.
2. If `ae` is not found, add Pub cache to `PATH`: `export PATH="$PATH:$HOME/.pub-cache/bin"`.
3. Install embedded core (when integrating in Dart code): `dart pub add agentic_executables_core --version <CORE_VERSION>`.
4. Install MCP adapter (optional): `dart pub add agentic_executables_mcp --version <MCP_VERSION>`.

## Configuration
- Set library id for scripts: `export AE_LIBRARY_ID=dart_agentic_executables`.
- Optional skill home: `export CODEX_HOME=<CODEX_HOME_PATH>`.
- Create `<PROJECT_ROOT>/ae.config.json`:
```json
{
  "library_id": "dart_agentic_executables",
  "engine": "<auto|codex|template>",
  "library_root": "<PROJECT_ROOT>",
  "output_dir": "<PROJECT_ROOT>/ae_use"
}
```

## Integration
- Verify CLI wiring: `ae definition`.
- Generate baseline AE files: `ae generate --library-id dart_agentic_executables --library-root <PROJECT_ROOT> --output-dir <PROJECT_ROOT>/ae_use --engine <auto|template>`.
- Fetch registry docs (post-publication): `ae registry get --library-id dart_agentic_executables --action install`.
- Install Codex skill (optional): `ae skill install --name ae-cli --target <SKILLS_DIR>`.

## Validation
- `ae definition` returns JSON with `"success": true`.
- `ae instructions --context library --action bootstrap` returns `ae_context.md` and `ae_bootstrap.md`.
- `rg --files <PROJECT_ROOT>/ae_use` lists `ae_install.md`, `ae_uninstall.md`, `ae_update.md`, `ae_use.md`.
- If a check fails, execute rollback/removal steps in `ae_uninstall.md`.
