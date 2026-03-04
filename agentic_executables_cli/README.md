# agentic_executables_cli

Primary CLI interface for Agentic Executables v2.

Binary: `ae`

Default output is JSON (agent-friendly). Use `--human` for readable text.

## Why CLI-First

The CLI gives one stable automation surface for both humans and agents:
- same command contract in local scripts, CI, and autonomous agents.
- machine-readable envelopes by default.
- predictable fallback behavior when Codex is unavailable.

## Audience

### For Humans

Use `ae` when you want to:
- bootstrap AE docs for a library quickly.
- run verify/evaluate checks before merge or release.
- fetch/publish registry artifacts without custom tooling.

### For Agents

Use `ae` when you need:
- deterministic JSON envelopes for parsing.
- strict action/context validation.
- generation via `auto|codex|template` with explicit error codes.

## Quick Start

```bash
cd agentic_executables_cli
dart pub get
dart run bin/ae.dart definition
```

If `ae` is not installed globally:

```bash
dart run bin/ae.dart <command> ...
```

## Command Surface

```bash
ae definition
ae instructions --context <library|project> --action <bootstrap|install|uninstall|update|use> [--resources-path <path>]
ae verify --input <json-file|->
ae evaluate --input <json-file|->
ae registry get --library-id <id> --action <install|uninstall|update|use>
ae registry submit --library-url <url> --library-id <id> --ae-use-files <csv|repeatable>
ae registry bootstrap-local --ae-use-path <path>
ae generate --library-id <id> --library-root <path> [--output-dir <path>] [--engine auto|codex|template] [--dry-run]
ae skill install [--target <skills-dir>] [--name ae-cli] [--force]
ae skill update [--target <skills-dir>] [--name ae-cli]
```

## Fast Use Cases

1. Library maintainer bootstrap:
   - `ae instructions --context library --action bootstrap`
   - `ae generate --library-id <id> --library-root <path> --engine auto`
   - `ae verify --input verify.json`
   - `ae evaluate --input evaluate.json`
2. Project integrator:
   - `ae registry get --library-id <id> --action install`
   - apply `ae_install.md`
3. Agent skill lifecycle:
   - `ae skill install`
   - `ae skill update`

## JSON Envelope

All responses use:

```json
{
  "success": true,
  "command": "definition",
  "data": {},
  "warnings": [],
  "meta": {
    "timing_ms": 12,
    "versions": {
      "cli": "0.1.0",
      "core": "2.0.0"
    }
  }
}
```

Errors include:

```json
"error": {
  "code": "validation_error",
  "message": "...",
  "details": "..."
}
```

## Generation Modes

- `auto`: use Codex when available; fallback to template.
- `codex`: require Codex; fail explicitly if unavailable.
- `template`: deterministic skeleton generation.

Codex execution defaults:
- primary: `codex exec --sandbox workspace-write --full-auto --output-schema <schema-path> --output-last-message <path> ...`
- compatibility fallback: `codex exec --sandbox workspace-write -a on-failure ...`

## Provider-Agnostic Inference

`AeCli` accepts optional `inferenceClient` to use non-Codex providers behind the same generation flow:

```dart
final cli = AeCli(inferenceClient: MyInferenceClient());
```

Guide: `../docs/inference_provider_guide.md`

## Verify/Evaluate Input Shape

Minimal `verify.json`:

```json
{
  "context_type": "project",
  "action": "install",
  "files_modified": [
    {
      "path": "ae_install.md",
      "loc": 140,
      "sections": ["Setup", "Config", "Integration", "Validation"]
    }
  ],
  "checklist_completed": {
    "modularity": true,
    "contextual_awareness": true,
    "agent_empowerment": true,
    "validation": true,
    "integration": true
  }
}
```

Minimal `evaluate.json`:

```json
{
  "context_type": "project",
  "action": "install",
  "files_created": [
    {
      "path": "ae_install.md",
      "loc": 140
    }
  ],
  "sections_present": ["Setup", "Config", "Integration", "Validation"],
  "validation_steps_exists": true,
  "integration_points_defined": true
}
```

## Skill Delivery

Skill template source: `skills/ae-cli/SKILL.md`

Install target resolution:
1. `$CODEX_HOME/skills/<name>` when `CODEX_HOME` is set.
2. `~/.codex/skills/<name>` otherwise.

## Testing

```bash
dart test
```

Integration-only:

```bash
dart test test/integration_test.dart
```
