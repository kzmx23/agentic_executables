---
title: "Concepts"
outline: deep
---

# Concepts

AE 3.0 turns your codebase into a navigable knowledge spine. It is a knowledge tool, not a documentation tool: a structured, language-agnostic record of what your code is supposed to do, kept honest by drift detection, with the heavy thinking delegated to whatever agent you already use.

This page lays out the four ideas the rest of the system is built on. Once they click, every command and file shape downstream reads as obvious.

## The four crystallizations

These are the load-bearing principles. The data model, the CLI, the MCP surface, and the plugin all fall out of them.

1. **Knowledge is canonical, code is realization.** The same canonical knowledge can describe a Dart implementation and a Rust implementation as two performances of one score. The score is reusable across languages and projects; the performances are not.
2. **AE composes with the agent rather than competing with it.** Heuristic extraction runs by default, in milliseconds, with no model. When LLM work is needed (distilling a canonical from real code, for instance), AE delegates to the host agent — Claude Code's Task tool, Codex `exec`, Cursor agent mode — through a strict wire format. BYOK direct-LLM exists as the fallback for headless and CI runs. AE never owns a model and never charges per token.
3. **Knowledge has two layers: canonical (intent) and artifact (instance).** Canonical is the score. Artifact is the performance. They reference each other; they are never the same thing. Conflating them is the original sin AE 2.x committed; 3.0 splits them deliberately.
4. **Canonical is a token-efficient cognitive map, not exhaustive documentation.** A pack targets ~10–50 features and ~2–4k tokens. Complex specs decompose into multiple sibling packs that compose. If you find yourself writing 80 features into one canonical, stop and split it. Real documentation tools already exist; this is something different.

## Canonical vs artifact, in one paragraph each

A **canonical pack** lives at `.ae_hub/canonical/<concept>/` and describes a load-bearing concept in language-agnostic terms: a list of features with a `spec` and an `invariant` per row, plus a ~600-word `index.md` that orients the reader. It carries license, sources, and authors as first-class metadata. It says nothing about Dart, Rust, files, or test runners. The score.

An **artifact pack** lives at `.ae_hub/artifacts/<kind>/<name>/` and describes one concrete instance — a Dart package, a Rust crate, an external standard you've imported. Its `meta.yaml` records source paths and SHA-256 file hashes. Its `references_canonical` list says which canonicals it claims to implement. Its `matrix.yaml` carries the cells (impl status, location, tests, notes) for each feature in those canonicals. Its `requires:` block records cross-artifact dependencies. The performance.

The two layers reference each other through stable feature IDs (`entity.create`, `system.tick`, `render.scene_extract`). When you `ae artifact link --pack X --canonical Y`, AE materializes matrix rows for the artifact, one per canonical feature, defaulting to `impl: missing`. You fill them in over time. Drift surfaces when invariants in the canonical aren't asserted by tests in the artifact, or when source files change without the artifact being re-synced.

## What AE 3.0 is not

It is not a documentation site generator, not a doc-comment harvester, not a wiki. It is not a code generator: cross-language port-by-LLM is explicitly post-3.x territory (see [Roadmap](./roadmap)). It does not auto-sync code to canonical — drift visibility is honest; auto-sync would lie. It is not a public knowledge hub yet; the resolver supports the layer, but remote sharing is roadmapped. It is not a team tool: 3.0 is solo-dev focused.

## Where to next

- [Quick start](./quick-start) — `ae init` to first tier-classified gap report in 60 seconds.
- [Hub layout](./hub-layout) — the directory tree, plus project / user / package / remote precedence.
- [Authoring canonicals](./authoring-canonicals) — granularity, attribution, the scaffold workflow.
- [Walkthroughs](./walkthroughs) — multi-language monorepo, glTF + KHR extensions, a hypothetical 2026 new-extension flow.
