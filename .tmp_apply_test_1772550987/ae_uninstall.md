# Uninstallation

## Prerequisites
- Set working directory: `cd <PROJECT_ROOT>`.
- Identify installed mode(s): `<AE_MODE_LIST>` from `cli`, `embedded`, `mcp`.
- Backup custom AE files if needed: `cp -R <PROJECT_ROOT>/ae_use <PROJECT_ROOT>/ae_use.backup.<DATE_TAG>`.

## Removal Steps
1. Remove generated AE artifacts: `rm -rf <PROJECT_ROOT>/ae_use` and `rm -f <PROJECT_ROOT>/ae.config.json`.
2. Remove embedded packages (if present): `dart pub remove agentic_executables_core` and `dart pub remove agentic_executables_mcp`.
3. Remove global CLI (if installed): `dart pub global deactivate agentic_executables_cli`.

## Cleanup
- Remove environment exports from shell profiles: `AE_LIBRARY_ID`, `CODEX_HOME`.
- Remove installed skill directory: `rm -rf <SKILLS_DIR>/ae-cli`.
- Clear temporary payload files: `rm -f <PROJECT_ROOT>/verify.json <PROJECT_ROOT>/evaluate.json`.

## Validation
- `which ae` returns no path when CLI mode is removed.
- `dart pub deps | rg agentic_executables` returns no matches for removed packages.
- `test ! -d <PROJECT_ROOT>/ae_use` succeeds.
- Run baseline project check: `<PROJECT_BASELINE_COMMAND>`.
