---
title: Overview
outline: deep
---

# What is Agentic Executables

## Purpose

Decide whether Agentic Executables (AE) fits your project and how **Know** and **Use** fit together before you install or integrate.

## Summary

Agentic Executables (AE) turns domain knowledge into executable instructions that humans and AI agents can run the same way — for libraries, apps, games, servers, or any implementation.

## 30-second answer

- You ship deterministic runbooks — install, uninstall, update, use — for any project: library, app, game, server, or protocol implementation.
- Humans get repeatable workflows.
- Agents get structured instructions and stable contracts.
- Teams get lower integration drift and safer rollback behavior.

## Two core capabilities

**Know** — extract domain knowledge from specs, docs, or repos (`ae know build`)

**Use** — turn knowledge into executable instructions (`ae generate`, `ae registry`)

They compose freely:

- **Know alone** — extract a spec and implement features directly from it
- **Use alone** — manage a project lifecycle with deterministic instructions
- **Know + Use** — generate domain-aware lifecycle files
- **Know + Use + Package** — produce deployment artifacts when needed (`ae package resolve`)

All artifacts live in a local-first **hub** that works offline and optionally syncs with remote registries.

## How this docs site is optimized

- Grouped navigation: **Start**, **Workflows**, **Build**, plus Troubleshooting and Reference.
- Every core page includes prerequisites, expected output, and failure recovery.
- Deterministic, machine-consumable outputs are published at:
  - `/llms.txt`
  - `/llms-full.txt`

## Built on open ideas

AE stands on the shoulders of the [llms.txt](https://llmstxt.org/) specification, the [Model Context Protocol](https://modelcontextprotocol.io/), [Jina Reader](https://r.jina.ai/), and many open-source projects. See [Acknowledgments](/reference/acknowledgments) for the full story.

## Verify

You understand that AE provides **Know** (extract domain knowledge) and **Use** (executable lifecycle instructions) in a **local-first hub**.

## If it fails

If terminology or scope is still unclear, open [Get Started](/get-started/) and pick a track by role, or see [Troubleshooting](/troubleshooting/).

## Next step

Go to [Get Started](/get-started/) and pick a track by role.
