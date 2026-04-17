# Claude Code AE Plugin

Surfaces AE 3.0 (Agentic Executables) inside Claude Code. After install, opening a project that contains a `.ae_hub/` directory triggers a hint suggesting `/ae-status` to inspect the canonical/artifact gap report.

## Install

1. Ensure the `ae` CLI is installed and on your `$PATH`. From this repo:
   ```bash
   ./install.sh
   ```
2. Copy or symlink this plugin directory into your Claude Code plugins folder. The exact location depends on your Claude Code installation; consult the Claude Code docs for the plugin loading convention used by your version.

## What it does

- **Hook:** `on_project_open.sh` checks for `.ae_hub/` and prints a one-line hint pointing at `/ae-status`.
- **Slash commands:** `/ae-status` runs `ae status` against the open project and surfaces the tier-classified gap report. `/ae-distill <pack> <concept>` dispatches a distillation subagent (the receiving end is the `ae-distill-skill`).
- **Skill:** `ae-distill-skill.md` teaches Claude what shape to return when given a `DistillationTask`. The wire format is `ae.distillation.task.v1` in / `ae.canonical.draft.v1` out — see the AE 3.0 design doc §7.
- **MCP:** auto-wires the AE MCP server so tools like `ae_init`, `ae_status`, `ae_canonical`, and `ae_artifact` are available to Claude.

## Spec reference

See `docs/superpowers/specs/2026-04-17-ae-3.0-design.md` §10 in this repo.
