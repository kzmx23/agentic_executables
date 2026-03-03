# AE Bootstrap
## Objective
- Generate and maintain compact library AE files (`ae_install.md`, `ae_uninstall.md`, `ae_update.md`, `ae_use.md`) that are executable, reversible, and validation-complete.

## Inputs
- `context_type`: Must be `library`.
- `action`: `bootstrap` for first generation or `update` for existing AE files.
- `library_id`: Registry key in `<language>_<library_name>` format.
- `library_root`: Path containing source, manifests, tests, and examples.
- `target_version`: Intended release or integration version.
- `current_version`: Existing version baseline for migration diffs.
- `existing_ae_dir`: Existing AE directory when already present.
- `constraints`: Policy limits for security, compatibility, CI, and style.

## Discovery
- Inspect manifests and lockfiles to extract dependency requirements and version constraints.
- Inspect source entry points to map setup paths, config surfaces, and integration seams.
- Inspect runtime resources to map cleanup targets for files, hooks, jobs, and secrets.
- Inspect changelog and API diffs to identify migrations, deprecations, and breaking changes.
- Inspect tests/examples to derive deterministic validation commands and expected outcomes.
- Inspect existing AE files to detect drift, stale versions, missing sections, and redundancy.
- Emit discovery matrix entries as `{artifact, finding, affected_file, validation_hook}`.

## Output Contracts
- Required outputs: `ae_install.md`, `ae_uninstall.md`, `ae_update.md`, `ae_use.md`.
- Optional output: `README.md` in the AE folder for maintainers.
- `ae_install.md` sections: `# Installation`, `## Prerequisites`, `## Installation Steps`, `## Configuration`, `## Integration`, `## Validation`.
- `ae_uninstall.md` sections: `# Uninstallation`, `## Prerequisites`, `## Removal Steps`, `## Cleanup`, `## Validation`.
- `ae_update.md` sections: `# Update`, `## Prerequisites`, `## Version Scope`, `## Migration Steps`, `## Rollback`, `## Validation`.
- `ae_use.md` sections: `# Usage`, `## Prerequisites`, `## Core Patterns`, `## Guardrails`, `## Validation`, `## Troubleshooting`.
- Template rule: use placeholders (`<path>`, `<command>`, `<old_version>`, `<new_version>`) instead of concrete language snippets.
- Install to uninstall reversibility matrix:
| Install artifact or step | Required uninstall reversal |
| --- | --- |
| Add dependency | Remove dependency and verify lockfile cleanup |
| Add configuration key or file | Remove key or file or restore previous value |
| Add imports or initialization wiring | Remove wiring and restore previous entry path |
| Add generated runtime artifact | Remove artifact and dependent references |
| Add permissions or secrets | Revoke permissions and remove secret references |
| Add background process or hook | Disable process or hook and verify stop state |
| Add install validation | Add removal validation proving rollback completeness |

## Generation Algorithm
1. Build required section skeletons for all output files before filling details.
2. Populate `ae_install.md` in lifecycle order: prerequisites, install, config, integration, validation.
3. Derive `ae_uninstall.md` by reversing each install step with one-to-one matrix mapping.
4. Populate `ae_update.md` from version diff data with ordered migrations and rollback triggers.
5. Populate `ae_use.md` with high-frequency patterns, guardrails, and validation checks.
6. Keep instructions template-only and parameterized with placeholders.
7. Add explicit pass criteria for every validation checkpoint.
8. Run quality gates and compress until all constraints pass.

## Update Algorithm
1. Load existing AE files and compare against required output contracts.
2. Preserve valid unchanged sections and rewrite only stale or drifted content.
3. Refresh version-sensitive instructions in install, update, and use files.
4. Recompute uninstall reversals from current install content, not prior uninstall text.
5. Regenerate migration steps and rollback logic from current diff evidence.
6. Revalidate every checkpoint against current project layout and toolchain.
7. Remove duplicated, conflicting, and obsolete instructions.
8. Fail update when any mandatory section or reversal mapping is missing.

## Quality Gates
- Gate 1 Structure: all required files exist with mandatory section headers in required order.
- Gate 2 Reversibility: each install step has a paired uninstall reversal.
- Gate 3 Migration: update file defines scope, ordered migrations, rollback triggers, and rollback steps.
- Gate 4 Validation: every file includes executable checkpoints and explicit expected outcomes.
- Gate 5 Consistency: placeholders, versions, terms, and paths are consistent across files.
- Gate 6 Safety: risky operations include prerequisites, safeguards, and recovery guidance.
- Gate 7 Compactness: instructions are concise, non-redundant, and within line budgets.

## Compression Rules
- Keep one instruction per line and one action per bullet.
- Prefer tables and checklists over repeated prose.
- Remove rationale text unless it changes execution behavior.
- Deduplicate repeated steps by referencing canonical step names.
- Collapse equivalent variants into parameterized placeholders.
- Keep headings stable and short; avoid decorative framing.
- Ban emojis, themed metaphors, and language-specific concrete snippets.

## Done Criteria
- Required output files exist and satisfy Output Contracts.
- Install and uninstall files are fully reversible via matrix mapping.
- Update file covers migration expectations, rollback, and validation.
- Use file covers core patterns, guardrails, and validation.
- Validation checkpoints are complete, executable, and action-specific.
- Quality Gates pass with no blocking failures.
- Output is compact, template-only, and ready for registry publication.
