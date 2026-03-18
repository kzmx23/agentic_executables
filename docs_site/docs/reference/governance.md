---
title: Ownership and Governance
outline: deep
---

# Ownership and Governance

This keeps docs accurate while AE evolves across CLI, Core, and MCP.

## Ownership model

- Product/docs owner: information architecture, onboarding funnel health.
- CLI owner: command behavior and examples stay current.
- MCP owner: tool contracts and payload docs stay current.

## Change policy

Any merge that changes CLI/MCP behavior must update relevant docs:

1. Update onboarding pages if first-run flow changed.
2. Update troubleshooting if error behavior changed.
3. Update agent contract docs if request/response semantics changed.

## Docs quality gates

- Markdown lint on all docs.
- Command snippet validation for AE examples.
- VitePress production build must pass.
- Dead-link and broken-anchor checks through strict docs build output.

## Review cadence

- Weekly: onboarding friction and install success review.
- Monthly: role-journey conversion review.
- Per release: docs regression review against release notes.
