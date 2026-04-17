# AE Error Code Playbook (v3)

This table is contract documentation for automation. Treat codes as stable identifiers.

| Code | Emitted By | Meaning | Retryable | Recovery Command |
| --- | --- | --- | --- | --- |
| `invalid_arguments` | CLI parser | Invalid CLI flags or malformed command usage | no | `ae <subcommand> --help` |
| `invalid_command` | CLI | Missing or unknown command/subcommand | no | `ae --help` |
| `validation_error` | CLI/Core/MCP | Required input missing or type/schema mismatch | no | `ae <subcommand> --help` and fix input payload |
| `internal_error` | CLI | Unhandled runtime exception in command handler | maybe | Re-run with `--human` and inspect diagnostics |
| `command_failed` | CLI envelope | Generic fallback for failed command without specific code | maybe | Re-run the command with corrected inputs |
| `definition_failed` | CLI | Failed to load AE definition data | maybe | `ae definition` |
| `instructions_failed` | Core/CLI | Failed to load prompt documents | maybe | `ae instructions --context <...> --action <...> --resources-path <valid-path>` |
| `verify_failed` | CLI | Verify execution failed unexpectedly | maybe | `ae verify --input <verify.json>` |
| `evaluate_failed` | CLI | Evaluate execution failed unexpectedly | maybe | `ae evaluate --input <evaluate.json>` |
| `generation_failed` | Core/CLI | Generation engine failed to produce output | maybe | `ae generate --library-id <id> --library-root <path> --engine template` |
| `engine_unavailable` | Core/CLI | Requested generation engine is not available | no | `ae generate --engine template ...` |
| `invalid_generation_output` | Core | Engine output missing required AE files | no | Re-run with `--engine template` and inspect generator |
| `inference_failed` | Core | External inference backend failed | maybe | Re-run or switch provider/engine |
| `inference_output_invalid` | Core | Inference response does not match required output schema | no | Fix provider output schema and retry |
| `codex_exec_failed` | CLI Codex adapter | `codex exec` invocation failed | maybe | Verify Codex installation and run `codex exec --help` |
| `codex_parse_failed` | CLI Codex adapter | Codex output could not be parsed as structured JSON | maybe | Re-run generation with `--engine template` |
| `registry_not_found` | Core/CLI | Requested library is absent from registry | no | Ask maintainer to submit files, then re-run `ae registry get ...` |
| `registry_fetch_failed` | Core/CLI | Registry file retrieval failed (network or source issue) | maybe | `ae registry get --library-id <id> --action <action>` |
| `registry_get_failed` | CLI | Wrapper-level failure around `registry get` | maybe | Re-run `ae registry get ...` |
| `registry_submit_failed` | CLI | Wrapper-level failure around `registry submit` | no | Validate submission parameters and retry |
| `registry_bootstrap_failed` | CLI | Wrapper-level failure around local registry bootstrap | no | `ae registry bootstrap-local --ae-use-path <path>` |
| `check_mode_changes_detected` | CLI safe writer | `--check` found drift that would change files | no | Apply changes by re-running without `--check` |
| `write_conflict_no_overwrite` | CLI safe writer | `--no-overwrite` blocked one or more writes | no | Re-run with `--backup` or remove `--no-overwrite` |
| `skill_upgrade_required` | CLI skill install | Installed skill differs and requires explicit upgrade | no | `ae skill install --upgrade [--target <dir>]` |
| `skill_missing` | CLI skill update | Skill update requested but target skill not installed | no | `ae skill install [--target <dir>]` |
| `skill_template_load_failed` | CLI skill install/update | Failed to read embedded or override skill template | no | Check `--template-path` and file permissions |
| `hub_init_failed` | CLI/Core | Hub directory initialization failed | maybe | Check permissions and retry `ae hub init` |
| `hub_not_found` | CLI/Core | No hub found at project or user level | no | `ae hub init` to create a hub |
| `hub_status_failed` | CLI | Failed to retrieve hub status | maybe | `ae hub status [--hub <path>]` |
| `hub_pull_failed` | CLI/Core | Failed to pull artifacts from remote hub | maybe | `ae hub pull --remote <name> --library-id <id>` |
| `hub_push_failed` | CLI/Core | Failed to generate push instructions for remote hub | maybe | `ae hub push --remote <name>` |
| `tool_failed` | MCP envelope | Generic MCP tool failure fallback | maybe | Re-run MCP call with validated typed payload |
| `doctor_checks_failed` | CLI `doctor` data payload (`failure_code`) | One or more critical preflight checks failed | no | `ae doctor --target <skills-dir>` and apply `fix_command` from failed checks |
| `no_hub` | CLI `init`, `status`, `sync`, `canonical`, `artifact` | No `.ae_hub` directory found at the resolved project root | no | `ae hub init --project` to create a project-level hub, then re-run |
| `unhandled_subdirs` | CLI `init` | `--strict` set and one or more sub-directories have no matching extractor | no | Drop `--strict`, or restructure/exclude the unhandled sub-directories |

## Notes

- `ae doctor` always returns structured check data. When critical checks fail, `data.overall_status` is `fail`, `data.failure_code` is `doctor_checks_failed`, and CLI exit code is non-zero.
- MCP v3 rejects legacy string-encoded JSON payloads for `ae_verify` and `ae_evaluate`.
