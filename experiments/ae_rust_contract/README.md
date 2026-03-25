# AE Rust contract experiment (greenfield stub)

This workspace is **not** a CLI port. It exists to lock **JSON/YAML shapes** exported from the Dart `ae` CLI for a possible future Rust implementation.

After a fresh clone, `spec/` is empty on purpose. Populate with `just e2e` (see below) or `parity-check` / tests will skip.

## Regenerate fixtures (recommended)

From the repository root (requires [Just](https://github.com/casey/just)):

```bash
just e2e
```

That rebuilds `.ae_hub`, writes `docs/feature_matrix.yaml`, and fills `experiments/ae_rust_contract/spec/` using `ae know plan --out` (no Python). Use `AE_E2E_EXTENDED=1 just e2e` to also smoke-test `instructions`/`generate`/`verify`/`evaluate`/`package`/`doctor` (see `docs/ae_e2e_log.md`).

### Manual export (same end state)

From the repository root (with `.ae_hub` populated):

```bash
dart run agentic_executables_cli/bin/ae.dart definition > experiments/ae_rust_contract/spec/definition.json
dart run agentic_executables_cli/bin/ae.dart know list --hub "$PWD/.ae_hub" > experiments/ae_rust_contract/spec/know_list.json
dart run agentic_executables_cli/bin/ae.dart know show --name ae_docs_know_design --hub "$PWD/.ae_hub" \
  > experiments/ae_rust_contract/spec/know_show_ae_docs_know_design.json
dart run agentic_executables_cli/bin/ae.dart know plan --name ae_docs_know_design --hub "$PWD/.ae_hub" \
  --out experiments/ae_rust_contract/spec/plan_ae_docs_know_design.md
cp docs/feature_matrix.yaml experiments/ae_rust_contract/spec/feature_matrix.yaml
```

## Minimal acceptance (parity)

- **`definition.json`:** top-level `{ "success": true, "data": { ... } }` parses.
- **`know_list.json`:** `data.packs` is a non-empty array.
- **`know_show_*.json`:** `data.content` is non-empty markdown; `data.meta` is an object.
- **`feature_matrix.yaml`:** `schema: ae.know.matrix.v1`, `version: 1`, non-empty `title`.
- **`plan_*.md`:** free-text contract for agents; no strict schema in Rust stub.

Run:

```bash
cd experiments/ae_rust_contract
cargo test
cargo run -p ae_cli_stub -- parity-check
```

## Intentional cuts

No Jina/HTML/PDF extractors, no git `--repo` extractor, no MCP, no on-disk hub layout replication—only serde checks against checked-in samples.
