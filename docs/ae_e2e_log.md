# AE local hub E2E log (agentic_executables)

**Last updated:** 2026-03-26  
**Hub:** `.ae_hub/` at repository root (from `ae hub init --project`).  
**CLI:** `dart run agentic_executables_cli/bin/ae.dart` from repo root (`dart pub get` in `agentic_executables_cli` first).

**Product / pipeline notes:** [`ae_know_extract_implement.md`](ae_know_extract_implement.md) (extract → implement → what to improve next).

## Repeatability (DX): reset and run again

- **One-shot local E2E + Rust spec export:** from repo root, `chmod +x scripts/ae_e2e_local_hub.sh` once, then:
  - `./scripts/ae_e2e_local_hub.sh run` — deletes `.ae_hub`, `docs/feature_matrix.yaml`, and `experiments/ae_rust_contract/spec/*` (except `.gitkeep`), then `dart pub get`, `hub init --project`, sharded `know build`, `matrix init` / `scaffold` / `diff`, and exports JSON/Markdown/YAML into `experiments/ae_rust_contract/spec/`.
  - `./scripts/ae_e2e_local_hub.sh reset` — wipe only (no rebuild).
  - Optional network smoke pack: `AE_E2E_NETWORK=1 ./scripts/ae_e2e_local_hub.sh run`.
  - Optional **downstream smoke** (`instructions --know`, `generate --know`, `verify`, `evaluate`, `package`, `doctor`): `AE_E2E_EXTENDED=1 ./scripts/ae_e2e_local_hub.sh run`.
- **`.gitignore`** ignores `.ae_hub/`, generated `docs/feature_matrix.yaml`, and `experiments/ae_rust_contract/target/` so the experiment stays out of git noise; force-add files if you intentionally want them tracked.
- **Rust stub:** `cargo test` / `parity-check` **skip** when `spec/definition.json` is missing (fresh clone); after `run`, use `cargo run -p ae_cli_stub -- parity-check`.

## Command matrix

| Area | Command(s) | Result | Notes |
|------|------------|--------|-------|
| Core | `definition` | works | JSON envelope; non-empty `data.definition`. |
| Hub | `hub init --project`, `hub status --hub <abs-path>` | works | Project hub under `.ae_hub`. |
| Hub | `hub pull` / `hub push` | not run | No remote configured; treat as **out of scope** for this pass. |
| Know | `know build --url file:///...`, `know build --path <file>` | works | `file://` reads via `PassthroughExtractor`; `--path` uses local source. |
| Know | `know list`, `know show`, `know diff`, `know migrate --dry-run` | works | |
| Know | `know plan --name <pack>` | works | After `matrix init`, plan includes matrix + index. |
| Know | `know matrix init`, `matrix scaffold`, `matrix diff` | works | Pass `--hub` on the `matrix` subcommand when needed. |
| Know | `know build --url https://...` | works | Smoke: Flutter `llms.txt` (network). |
| Instructions | `instructions --context library --action bootstrap [--know <name>]` | works | Resolves project `.ae_hub` by walking up from cwd (`FileHubResolver`). |
| Generate | `generate --engine template --dry-run [--know <name>]` | works | Same hub resolution as instructions. |
| Registry | `registry get --library-id dart_mcp --action install --check` | partial | Completes with `registry_not_found` (library not published). Not a hang when using a valid check. |
| Registry | `registry bootstrap-local --ae-use-path ...` | works | Instructional payload for local registry layout. |
| Package | `package resolve` / `package validate --instructions <file>` | works | Validate needs full v3 shape including `profile` (use resolve output file). |
| Verify / Evaluate | `verify --input docs/ae_e2e_verify.json`, `evaluate --input docs/ae_e2e_evaluate.json` | works | Fixtures align with `docs/error_code_playbook.md` contracts. |
| Doctor | `doctor` | works | Registry URL reachable in this environment. |
| Skill | `skill install --target /tmp/...` | works | Non-destructive temp target. |
| MCP | `ae_know` / `ae_hub` | not run | Optional parity; CLI exercised above. |

## Self-ingestion packs (sharded)

| Pack name | Source | ~tokens (`token_estimate`) |
|-----------|--------|----------------------------|
| `ae_docs_know_design` | `docs/ae_know_design.md` (file URL) | 2617 |
| `ae_docs_error_codes` | `docs/error_code_playbook.md` | 1791 |
| `ae_docs_site_know_index` | `docs_site/docs/know/index.md` | 2394 |
| `ae_pkg_cli_readme` | `agentic_executables_cli/README.md` | 705 |
| `ae_pkg_mcp_readme` | `agentic_executables_mcp/README.md` | 407 |
| `ae_url_smoke_flutter_llms` | `https://docs.flutter.dev/llms.txt` | 4198 |

Primary pack for matrix/plan: **`ae_docs_know_design`**. Repo-level matrix file: **`docs/feature_matrix.yaml`** (from `know matrix scaffold`).

## Limits (honest)

- **Scale:** Largest smoke pack (`ae_url_smoke_flutter_llms`) ~4.2k token estimate; sharding keeps individual `know show` payloads manageable.
- **Single `--know`:** `instructions` and `generate` accept one pack name; large repos still need multiple scripted invocations or a future **bundle / default pack set** in `hub.yaml`.
- **Registry:** `registry get` fails fast for unknown ids; publishing is a separate workflow.
- **Rust rewrite:** Out of scope for production parity; see `experiments/ae_rust_contract/README.md` for fixture-level acceptance only.

## Large-codebase workflow (patterns validated)

- **Shard by concern:** separate `know build` names (`ae_pkg_*`, `ae_docs_*`) so agents pick 2–3 relevant packs.
- **Stable prefixes:** predictable names for scripts and docs.
- **Repo-level matrix:** `matrix scaffold` → edit `docs/feature_matrix.yaml` for cross-cutting status without one mega-pack.
- **Friction logged for product follow-up:** multi-pack selection for `--know`, optional `know build --path <dir>` shard mode, MCP one-call multi-pack attach.

## Contributor smoke question

*Can a new contributor pick 2–3 `--know` names and get enough context without reading the whole hub?*  
**Yes**, using e.g. `ae_docs_know_design` + `ae_pkg_cli_readme` + `ae_docs_error_codes`, assuming the hub is populated as above.
