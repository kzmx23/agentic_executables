---
title: "Claude Code plugin"
outline: deep
---

# Claude Code plugin

`plugins/claude-code-ae-plugin/` is the moment AE stops being "another CLI" and becomes invisible scaffolding the agent uses. It bundles a project-open hook, two slash commands, the distillation skill that teaches Claude what JSON to return, and the MCP server auto-wiring. A Cursor-flavored equivalent is roadmapped (see [Roadmap → 3.1](./roadmap#three-one-fast-follow)).

## What's in the plugin

```text
plugins/claude-code-ae-plugin/
  plugin.json                         # manifest (name, version, hooks, slash, skills, mcp)
  hooks/
    on_project_open.sh                # detects .ae_hub/, surfaces it to Claude
  slash_commands/
    ae-status.md                      # /ae-status — wraps `ae status`
    ae-distill.md                     # /ae-distill <pack> <concept> — manual distillation flow
  skills/
    ae-distill-skill.md               # the distillation contract (ae.canonical.draft.v1)
  mcp/
    ae-mcp-config.json                # auto-wires AE MCP server
```

## Install

The plugin is installed like any Claude Code plugin: point Claude Code at the plugin directory, or symlink it into the user's plugin path. The `plugin.json` declares `claudeCode.minVersion: 1.0.0` and one `ProjectOpen` hook. After installation, opening a project that contains a `.ae_hub/` directory triggers `hooks/on_project_open.sh`, which surfaces the hub's presence and the canonicals it contains so Claude can offer to load them into context.

## Slash commands

### `/ae-status`

Runs `ae status` against the current project root and pretty-prints the tier-classified report. Equivalent to typing `ae status` in a terminal but kept inside the chat surface — useful for "what should I work on next?" without context-switching. See [CLI reference → `ae status`](./cli-reference#ae-status).

### `/ae-distill <pack> <concept>`

Dispatches a distillation: turn an artifact pack into a canonical pack. The slash command (see `slash_commands/ae-distill.md` in the plugin) walks Claude through:

1. Confirming the artifact exists (`ae artifact list`).
2. Building a `DistillationTask` per the wire format (the skill below teaches the shape).
3. Reading the artifact's `index.md`, `meta.yaml`, and source files referenced by `meta.source.files`.
4. Returning a `DistillationOutput` validated against `ae.canonical.draft.v1`.

Now that `ae canonical distill --pack <pack> --concept <concept>` is wired through to a `DistillationService` (commit `5c6bcd8`), the slash command's role shifts to orientation — running the underlying CLI is the recommended path; the slash command remains for the manual review-and-merge flow.

## The distillation skill

`skills/ae-distill-skill.md` is what makes this work. It teaches Claude the exact JSON shape AE expects back: `ae.canonical.draft.v1` with an `index_md`, a `matrix` (column schema + features), and an optional `patterns_md`. AE validates the response against the schema and retries once on failure with the validation error included as additional context (see spec §7). On a second failure AE refuses to merge — there is no silent partial accept.

This is the bit that lets AE outsource heavy thinking without giving up determinism. The skill is the contract; AE is the validator; Claude is the executor.

## MCP auto-wiring

`mcp/ae-mcp-config.json` registers the `agentic_executables_mcp` server with Claude Code. After plugin installation, the [twelve AE MCP tools](./mcp-reference) are available alongside Claude's built-ins — `ae_status`, `ae_canonical`, `ae_artifact`, and the rest. No manual MCP config in the user's settings; the plugin handles it.

## Cursor and others

The plugin shape is intentionally generic — slash commands, skills, MCP config, a project-open hook. A Cursor flavor is on the [3.1 fast-follow list](./roadmap#three-one-fast-follow). Other agent hosts (Zed, Continue, etc.) can wire the MCP server directly and skip the slash-command and hook layers.

## Where to next

- [MCP tools reference](./mcp-reference) — the tools the plugin auto-wires.
- [Authoring canonicals → Distill workflow](./authoring-canonicals#the-scaffold-workflow) — what `/ae-distill` is for.
- [Roadmap](./roadmap) — Cursor flavor and beyond.
