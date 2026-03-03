# Changelog

All notable changes to this project are documented in this file.

The format is based on [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
