<!-- ae-cli-skill-version: 1.0.0 -->
# ae-cli

Use this skill to operate Agentic Executables through the `ae` CLI.

## Quick Commands

- Definition:
  - `ae definition`
- Instructions:
  - `ae instructions --context library --action bootstrap`
  - `ae instructions --context project --action install`
- Verify:
  - `ae verify --input verify.json`
- Evaluate:
  - `ae evaluate --input evaluate.json`
- Registry:
  - `ae registry get --library-id <id> --action install`
  - `ae registry submit --library-url <url> --library-id <id> --ae-use-files ae_use/ae_install.md,ae_use/ae_uninstall.md,ae_use/ae_update.md,ae_use/ae_use.md`
  - `ae registry bootstrap-local --ae-use-path <path>`
- Generate:
  - `ae generate --library-id <id> --library-root <path> --engine auto`

## Action Recipes

### Bootstrap
1. Run `ae instructions --context library --action bootstrap`.
2. Run `ae generate --library-id <id> --library-root <path> --engine auto`.
3. Verify with `ae verify --input <json-file>`.
4. Evaluate with `ae evaluate --input <json-file>`.

### Install
1. Run `ae instructions --context project --action install`.
2. Optionally fetch registry file with `ae registry get --library-id <id> --action install`.
3. Execute install workflow from AE file.

### Uninstall
1. Run `ae instructions --context project --action uninstall`.
2. Optionally fetch registry file with `ae registry get --library-id <id> --action uninstall`.
3. Execute cleanup and verification steps.

### Update
1. Run `ae instructions --context project --action update`.
2. Optionally fetch registry file with `ae registry get --library-id <id> --action update`.
3. Run migration and validation steps.

### Use
1. Run `ae instructions --context project --action use`.
2. Optionally fetch registry file with `ae registry get --library-id <id> --action use`.
3. Apply workflow/actions/guidelines from AE docs.

## Skill Maintenance

- Install skill:
  - `ae skill install`
- Update skill:
  - `ae skill update`
