# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-03-03

### Added

- MCP v2 thin adapter (`AeMcpAdapter`) backed by `agentic_executables_core`
- New v2 tool set:
  - `ae_definition`
  - `ae_instructions`
  - `ae_generate`
  - `ae_registry`
  - `ae_verify`
  - `ae_evaluate`
- v2 response envelope (`success`, `data`, `error`, `warnings`, `meta`)

### Changed

- Major refactor to shared core architecture
- MCP now delegates domain logic to core services

### Removed

- Legacy tool names and contracts

### Migration Map (old -> new)

- `get_agentic_executable_definition` -> `ae_definition`
- `get_ae_instructions` -> `ae_instructions`
- `manage_ae_registry` -> `ae_registry`
- `verify_ae_implementation` -> `ae_verify`
- `evaluate_ae_compliance` -> `ae_evaluate`

## [0.1.0] - 2025-10-08

### Added

- Initial release of Prompts Framework MCP Server
