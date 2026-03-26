# AE Rust contract experiment

This crate is **not** a CLI port and **must not grow** over time. It exists only to answer: **how far do exported JSON/YAML shapes (from know packs + `ae spec export`) go without a second implementation?**

**Policy:** prefer **removing** code here over adding checks. Contracts and behavior live in **Dart + manifests + hub**; this folder stays thin serde against fixtures.

After a fresh clone, `spec/` is empty on purpose. Populate with `just e2e` (see below) or `parity-check` / tests will skip.

## Regenerate fixtures (recommended)

From the repository root (requires [Just](https://github.com/casey/just)):

```bash
just e2e
```

That rebuilds `.ae_hub`, writes `docs/feature_matrix.yaml`, and fills `experiments/ae_rust_contract/spec/` via **`ae spec export`**. Know packs come from [`docs/e2e_know_sources.yaml`](../../docs/e2e_know_sources.yaml). Use `AE_E2E_EXTENDED=1 just e2e` for downstream smoke (see [`docs/ae_e2e_log.md`](../../docs/ae_e2e_log.md)). Optional `AE_E2E_LOCALE` sets locale in `spec_index.json` and plan front matter. Optional **`AE_E2E_MATRIX_BASELINE`** adds `matrix_diff.json` during export (see [`docs/ae_e2e_log.md`](../../docs/ae_e2e_log.md)).

### Manual export (same end state)

From the repository root (with `.ae_hub` and `docs/feature_matrix.yaml`):

```bash
dart run agentic_executables_cli/bin/ae.dart spec export \
  --out experiments/ae_rust_contract/spec \
  --hub "$PWD/.ae_hub" \
  --matrix "$PWD/docs/feature_matrix.yaml" \
  --manifest "$PWD/docs/e2e_know_sources.yaml" \
  --locale en
```

Optional: `--matrix-baseline <prior.yaml>` writes `matrix_diff.json`.

## Minimal acceptance (parity)

- **`spec_index.json`:** `schema` is **`spec_export.v2`**, `version` **`2`**, `export_base` **`.`**, non-empty `locale`, `definition_yaml` / `definition_md` / `definition_json`, optional `matrix_diff` / `e2e_manifest`, `packs` lists `know_show` + `plan` per pack.
- **`definition.json`:** schema **`ae.spec_definition_ptr.v1`** (pointer to YAML + MD only).
- **`definition.yaml`:** schema **`ae.definition.v1`**, `version: 1`, non-empty `name` / `description`.
- **`definition.md`:** non-empty human-oriented text.
- **`know_list.json`:** non-empty `data.packs`.
- **Per pack:** each referenced JSON parses; `data.content` non-empty; `data.meta.source.path` for **`local`** sources is **relative** when export is run from repo root; plan markdown non-empty.
- **`feature_matrix.yaml`:** `schema: ae.know.matrix.v1`, `version: 1`, non-empty `title`.
- **`matrix_diff.json` (optional):** parses; includes `summary` when present in `spec_index`.

Run:

```bash
cd experiments/ae_rust_contract
cargo test
cargo run -p ae_cli_stub -- parity-check
```

**CI:** use **`parity-check --strict`** or **`AE_PARITY_REQUIRE_SPEC=1`** so a missing `spec/` fails (exit **2**), not a silent skip (exit **0**).

## Parity layers

See the **Parity pyramid** table in [`docs/ae_e2e_log.md`](../../docs/ae_e2e_log.md) (L0–L5). This crate implements **L0–L2** checks only.

## Intentional cuts

No extractors, no MCP, no hub replication—only checks on **exported** samples.
