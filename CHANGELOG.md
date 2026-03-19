# Changelog

All notable changes to this project are documented in this file.

The format is based on [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Canonical know storage**: source identity is canonical; names are aliases. Same source (e.g. same PDF URL) built under different names converges to one pack. New layout: `know/{type}/{format}/{sourceId}/versions/{contentSha}/` with `know/_aliases/{name}.yaml` for name resolution.
- **On-conflict policy** for `ae know build`: `--on-conflict reuse|update|fail|new_version` (CLI) and `on_conflict` (MCP). Build output includes `canonical_source_id`, `canonical_path`, `alias_attached`, `conflict_resolution`.
- **Migration**: `ae know migrate [--dry-run]` to collapse legacy name-keyed packs into canonical layout and generate the alias index. Idempotent; run twice with no changes on second run.
- First-class PDF support for `ae know build`: new `--format pdf` and auto-detection for URLs ending in `.pdf` or containing `/pdf/` (e.g. arXiv). PDFs are converted to markdown via Jina Reader and stored as knowledge packs.

## [2.0.0] - 2026-03-03

### Added

- New shared package: `agentic_executables_core`
- New CLI-first package: `agentic_executables_cli` (`ae` binary)
- Deterministic template generation engine in core
- Optional Codex execution engine in CLI with `auto|codex|template` mode
- Provider-agnostic inference abstraction for custom non-Codex implementations
- Repo-managed skill template at `skills/ae-cli/SKILL.md`
- CLI commands for `skill install` and `skill update`

### Changed

- Architecture moved to 3-package model: core + CLI + MCP thin adapter
- MCP package moved to v2 contracts and tool names
- CLI is now the primary AE interaction surface

### Removed

- Backward compatibility for old MCP tool contracts

## [1.1.0] - 2025-10-13

- moved registry to separate repository: https://github.com/fluent-meaning-symbiotic/agentic_executables_registry
- `ae_use_registry` folder is now a demo folder

## [1.0.0] - 2025-10-13

### Added

- Initial release.
