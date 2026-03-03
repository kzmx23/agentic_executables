# agentic_executables_cli

CLI-first interface for Agentic Executables v2.

Binary: `ae`

Default output mode is JSON. Use `--human` for readable output.

## Quick Start

```bash
cd agentic_executables_cli
dart pub get
dart run bin/ae.dart definition
```

If `ae` is not globally available, run commands as:

```bash
dart run bin/ae.dart <command> ...
```

## Commands

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

## JSON Envelope

All command responses follow:

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

Example success output:

```json
{
  "success": true,
  "command": "definition",
  "data": {
    "definition": {
      "name": "Agentic Executables (AE)"
    }
  },
  "warnings": [],
  "meta": {
    "timing_ms": 4,
    "versions": {
      "cli": "0.1.0",
      "core": "2.0.0"
    }
  }
}
```

## Generation Engine Behavior

- `auto`: use Codex when available, otherwise template fallback
- `codex`: require Codex binary or fail explicitly
- `template`: deterministic skeleton generation

Codex safe defaults:
- primary: `codex exec --sandbox workspace-write --full-auto --output-schema <schema-path> --output-last-message <path> ...`
- compatibility fallback: `codex exec --sandbox workspace-write -a on-failure ...`

## Provider-Agnostic Inference

`AeCli` accepts an optional `inferenceClient` so the `codex` generation slot can run any provider implementation:

```dart
final cli = AeCli(inferenceClient: MyInferenceClient());
```

Use this to implement OpenAI API based generation, local model adapters, or other hosted providers without changing core generation logic.

Reference guide:
- `../docs/inference_provider_guide.md`

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

`ae skill install` and `ae skill update` use the repo template at:

- `skills/ae-cli/SKILL.md`

Install target resolution:
1. `$CODEX_HOME/skills/<name>` when `CODEX_HOME` is set
2. `~/.codex/skills/<name>` otherwise

## Testing

```bash
dart test
```

Run integration test only:

```bash
dart test test/integration_test.dart
```
