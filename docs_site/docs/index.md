---
title: What is Agentic Executables
outline: deep
---

# Agentic Executables

Agentic Executables (AE) turns domain knowledge into executable instructions that humans and AI agents can run the same way — for libraries, apps, games, servers, or any implementation.

<div class="ae-hero">
  <div class="ae-hero-content">
    <span class="ae-hero-badge">Docs as Executables</span>
    <h2>Define once. Reuse anywhere.</h2>
    <p>AE packages install, update, use, and rollback behavior into deterministic command flows for humans and AI agents.</p>
  </div>
  <div class="ae-hero-wordmark">
    <span class="ae-logo-ascii">AE</span>
    <span class="ae-logo-sub">v3</span>
  </div>
</div>

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

## Start in under 5 minutes

<div class="journey-grid">
  <div class="journey-card">
    <h3>New here</h3>
    <p>Understand AE and run your first command quickly.</p>
    <p><a href="/get-started/beginner">Beginner track</a></p>
  </div>
  <div class="journey-card">
    <h3>Developer</h3>
    <p>Install fast and run a practical workflow.</p>
    <p><a href="/get-started/developer">Developer track</a></p>
  </div>
  <div class="journey-card">
    <h3>AI agent integrator</h3>
    <p>Use machine-friendly docs and MCP flows.</p>
    <p><a href="/get-started/agent">Agent track</a></p>
  </div>
  <div class="journey-card">
    <h3>Knowledge builder</h3>
    <p>Extract domain knowledge and build AI-agent-ready instructions.</p>
    <p><a href="/know/">Knowledge extraction</a></p>
  </div>
</div>

## How this docs site is optimized

- Task-first navigation (`Get Started`, `Install`, `Use`, `Develop`).
- Every core page includes prerequisites, expected output, and failure recovery.
- Deterministic, machine-consumable outputs are published at:
  - `/llms.txt`
  - `/llms-full.txt`

## Built on open ideas

AE stands on the shoulders of the [llms.txt](https://llmstxt.org/) specification, the [Model Context Protocol](https://modelcontextprotocol.io/), [Jina Reader](https://r.jina.ai/), and many open-source projects. See [Acknowledgments](/reference/acknowledgments) for the full story.

## Next step

Go to [Get Started](/get-started/) and pick a track by role.
