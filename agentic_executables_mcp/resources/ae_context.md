# AE Context
## Purpose
- Define the minimal shared contract for creating and executing Agentic Executable (AE) documents.
- Standardize terms, file boundaries, and quality rules across library and project contexts.

## Canonical Terms
- AE: A library treated as an executable artifact managed by instruction files.
- Library context: Maintainer mode for generating and updating AE files.
- Project context: Consumer mode for applying AE files in a codebase.
- Lifecycle stage Installation: Add dependencies and establish baseline setup.
- Lifecycle stage Configuration: Set required options, environment, and runtime settings.
- Lifecycle stage Integration: Wire library APIs into project entry points and flows.
- Lifecycle stage Usage: Apply library capabilities through repeatable task patterns.
- Lifecycle stage Uninstallation: Remove dependencies and reverse integration safely.
- Action `bootstrap`: Create or refresh core AE files for a library.
- Action `install`: Apply installation, configuration, and integration instructions.
- Action `uninstall`: Remove prior integration and installed dependencies.
- Action `update`: Move from current version or state to target version or state.
- Action `use`: Generate or apply frequent-operation usage rules.

## Context-Action Matrix
| Context | Allowed actions | Required docs |
| --- | --- | --- |
| library | bootstrap, update | ae_context.md + ae_bootstrap.md |
| project | install, uninstall, update, use | ae_context.md + ae_use.md |

## Core Principles
1. Agent Empowerment: Write instructions that allow autonomous execution with minimal clarification.
2. Modularity: Separate stages and responsibilities so actions are composable and replaceable.
3. Contextual Awareness: Include enough domain context to choose correct integration points.
4. Reversibility: Define uninstall and rollback paths that restore a stable pre-change state.
5. Validation: Require explicit checkpoints after installation, integration, updates, and removal.
6. Documentation Focus: Optimize for compact machine parsing over narrative explanation.

## File Responsibilities
| File | Primary owner | Responsibility |
| --- | --- | --- |
| ae_context.md | framework maintainer | Define global terms, principles, and constraints. |
| ae_bootstrap.md | library maintainer agent | Generate and update library AE operation files. |
| ae_use.md (core) | project execution agent | Execute install, use, update, and uninstall workflows. |
| ae_install.md | library maintainer agent | Specify install, configuration, integration, and validation steps. |
| ae_uninstall.md | library maintainer agent | Specify reverse operations and removal validation. |
| ae_update.md | library maintainer agent | Specify migration, rollback, and update validation steps. |
| ae_use.md (library output) | library maintainer agent | Specify frequent usage patterns and guardrails. |

## Minimal File Skeletons
- `ae_install.md`: `# Installation` + `## Prerequisites` + `## Installation Steps` + `## Configuration` + `## Integration` + `## Validation`.
- `ae_uninstall.md`: `# Uninstallation` + `## Prerequisites` + `## Removal Steps` + `## Cleanup` + `## Validation`.
- `ae_update.md`: `# Update` + `## Prerequisites` + `## Migration Steps` + `## Rollback` + `## Validation`.
- `ae_use.md` (library output): `# Usage` + `## Prerequisites` + `## Patterns` + `## Validation` + `## Troubleshooting`.

## Quality Constraints
- LOC target: keep each AE file under 500 lines.
- LOC warning: 500-800 lines requires compaction before release.
- LOC fail: over 800 lines blocks acceptance.
- Keep every instruction atomic, imperative, and directly executable.
- Keep templates abstract; use placeholders like `<path>`, `<command>`, and `<version>`.
- Keep required headings stable; do not rename section contracts.

## Authoring Rules
- Use short bullets or ordered steps; avoid long prose paragraphs.
- Use one responsibility per step and one validation outcome per checkpoint.
- Use explicit paths, commands, and expected outputs in template form.
- Ban emojis, themed framing, motivational text, and language-specific examples.
- Preserve filename contracts and tool-facing schemas without modification.
