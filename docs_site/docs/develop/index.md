---
title: Develop and Extend
outline: deep
---

# Develop and Extend

AE is split into core, CLI, and MCP adapter packages.

## Architecture map

### Package structure

- `agentic_executables_core/`: typed business logic, ports, adapters, and service contracts
- `agentic_executables_cli/`: `ae` executable interface
- `agentic_executables_mcp/`: MCP-facing adapter

### Capability model

```text
                    ┌→ Implement directly (human/agent reads knowledge)
ae know build ──────┤
                    └→ ae generate --know ──┬→ hub/use/{project}/
                                            └→ ae package (optional)
```

### Core service map

| Service | Purpose |
|---------|---------|
| `AeHubService` | Hub init, status, pull, push |
| `AeKnowService` | Build, list, show, remove, update, diff knowledge packs |
| `AeGenerationService` | Generate ae_use files (template or inference engine) |
| `AeRegistryService` | Fetch/submit to remote registry |
| `AeInstructionService` | Load context-appropriate prompt documents |
| `AeValidationService` | Verify and evaluate AE compliance |

### Port/adapter pattern

All external I/O flows through ports (interfaces) with swappable adapters:

- `HubResolver` → `FileHubResolver`
- `KnowledgeExtractor` → `PassthroughExtractor`, `UrlExtractor`, `RepoExtractor`
- `KnowledgeStore` → `FileKnowledgeStore`
- `RegistryClient` → `GitHubRawRegistryClient`
- `GenerationEngine` → `TemplateGenerationEngine`, `InferenceGenerationEngine`

## Local development

```bash
cd agentic_executables_core && dart test
cd ../agentic_executables_cli && dart test
cd ../agentic_executables_mcp && dart test
```

## Design and DX references

- [Design FAQ](https://github.com/fluent-meaning-symbiotic/agentic_executables/blob/main/DESIGN_FAQ.md)
- [DX FAQ](https://github.com/fluent-meaning-symbiotic/agentic_executables/blob/main/DX_FAQ.md)
- [Architecture diagram](https://github.com/fluent-meaning-symbiotic/agentic_executables/blob/main/docs/architecture_diagram.md)

## Contribution rule for docs quality

Any CLI or MCP behavior change must update:

1. `Get Started` or `Install` docs if onboarding impact exists.
2. Error/recovery docs when new codes or failure modes are introduced.
3. Agent contract docs when payload shape changes.
