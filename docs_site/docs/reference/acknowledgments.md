---
title: Acknowledgments
outline: deep
---

# Acknowledgments

AE builds on ideas, standards, and open work from many contributors and communities. This page gives credit where it's earned.

## Origins

The Agentic Executables concept was first articulated in October 2025 by [Anton Malofeev](https://github.com/Arenukvern) in the article [Reimagine Libraries Management as Apps using Agentic Executable Framework](https://dev.to/arenukvern/reimagine-libraries-management-as-apps-using-agentic-executable-framework-ami). The core insight: treat libraries and packages not as abstract reusable code, but as executable programs with standardized install, configure, use, and uninstall behavior — the same way you install an app on your phone.

That article is Part 4 of the [Dev Architecture Series](https://dev.to/arenukvern) which explores how AI agents change the way we build software. The series continues with planned parts on maintaining libraries with AI agents, domain knowledge extraction (which became `ae know`), and AI project bootstrapping.

From that original idea, AE evolved into two composable core capabilities: **Know** (extract domain knowledge from any source) and **Use** (turn knowledge into executable instructions). Together they cover any project type — libraries, apps, games, servers, protocol implementations — with optional deployment packaging when needed.

## Standing on shoulders

### llms.txt specification

The [`/llms.txt` proposal](https://llmstxt.org/) by Jeremy Howard and the Answer.AI team introduced the idea of publishing concise, markdown-formatted site summaries specifically for LLM consumption. AE's knowledge extraction pipeline (`ae know`) and this docs site's own `/llms.txt` and `/llms-full.txt` outputs are direct descendants of that idea.

- [llmstxt.org](https://llmstxt.org/) — the specification
- [llms-txt-hub](https://github.com/thedaviddias/llms-txt-hub) by David Dias — the largest directory of sites implementing llms.txt
- [llmstxt.cloud](https://directory.llmstxt.cloud/) — community directory of llms.txt files

### Model Context Protocol

The [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) by Anthropic established the pattern of structured tool-use for AI agents. AE's MCP adapter (`ae_definition`, `ae_instructions`, `ae_generate`, `ae_registry`, `ae_hub`, `ae_know`) follows MCP conventions directly.

The MCP team also publishes their full docs as [`llms-full.txt`](https://modelcontextprotocol.io/llms-full.txt), which we use as a primary test case for `ae know build`.

### Jina Reader API

[Jina AI's Reader API](https://r.jina.ai/) (`https://r.jina.ai/<url>`) powers AE's HTML-to-markdown extraction path. When you run `ae know build --format html`, the URL extractor proxies through Jina Reader to convert web pages into clean markdown. This is the kind of public infrastructure that makes the whole ecosystem better.

### nbdev and fastcore

The [nbdev](https://nbdev.fast.ai/) project by fast.ai pioneered automatic generation of `.md` versions of documentation pages, making the llms.txt ecosystem practical at scale. Many of the patterns in AE's knowledge extraction flow — treating docs as structured, machine-readable artifacts — trace back to nbdev's philosophy.

## Tools and projects that shaped AE

### Dart and Flutter ecosystem

AE is built in Dart. The package structure, pub conventions, and the `args` package for CLI parsing are foundational.

### VitePress

This documentation site runs on [VitePress](https://vitepress.dev/). Clean, fast, markdown-first — exactly what a docs-as-product surface needs.

### markdown.new

[markdown.new](https://markdown.new/) provides on-demand HTML-to-markdown conversion. While AE uses Jina Reader programmatically, markdown.new is the go-to for manual spec conversion and was an early influence on the `ae know` design.

## Contributors

AE is maintained by [Arenukvern](https://github.com/Arenukvern) and contributors at [fluent-meaning-symbiotic](https://github.com/fluent-meaning-symbiotic).

Contributions, ideas, and feedback from the open-source community shape every release.

## The philosophy

AE exists because domain knowledge is too hard to transfer. Specs sit in PDFs. Docs rot in wikis. Setup instructions live in someone's head. The llms.txt community showed that making knowledge machine-readable isn't just possible — it's a 50-line script away from being standard.

AE takes that further for any project type: **Define once. Reuse anywhere.**

If your project publishes an `llms.txt`, provides a clean spec URL, or maintains good README/docs — you've already done the hard part. AE just makes it actionable.
