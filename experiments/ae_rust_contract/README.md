# AE Rust contract experiment

This crate is **not** a CLI port and **must not grow** over time. It exists only to answer: **how far do exported JSON/YAML shapes from `ae spec export` (v3) go without a second implementation?**

Per spec §9.5, this is the **first non-Dart canonical consumer**: it reads canonical + artifact matrices and reports Tier 1/2 gaps against the contract.

**Policy:** prefer **removing** code here over adding checks. Contracts and behavior live in **Dart + manifests + hub**; this folder stays thin serde against fixtures.

After a fresh clone, `spec/` ships with minimal hand-crafted v3 fixtures. To regenerate from a real hub, use `ae spec export`.

## Regenerate fixtures

From the repository root:

```bash
dart run agentic_executables_cli/bin/ae.dart spec export \
  --out experiments/ae_rust_contract/spec \
  --hub "$PWD/.ae_hub" \
  --locale en
```

This emits:
- `spec_index.json` — schema `spec_export.v3`
- `definition.{yaml,md,json}` — framework definition trio
- `canonical_<slug>.json` — one per canonical pack (schema `ae.canonical.v3`)
- `artifact_<name>.json` — one per artifact pack (schema `ae.artifact.v3`)

## Minimal acceptance (parity-check)

- **`spec_index.json`:** schema `spec_export.v3`, version `3`, `export_base` `.`, non-empty `locale`, arrays `canonicals` and `artifacts`.
- **`definition.json`:** schema `ae.spec_definition_ptr.v1`.
- **`definition.yaml`:** schema `ae.definition.v1`, version `1`.
- **`definition.md`:** non-empty.
- **Per canonical file:** schema `ae.canonical.v3`; `meta.schema == ae.canonical.meta.v1`; `matrix.schema == ae.canonical_matrix.v1`; non-empty `matrix.features`.
- **Per artifact file:** schema `ae.artifact.v3`; `meta.schema == ae.artifact.meta.v1`; `matrix.schema == ae.artifact_matrix.v1`.

## Gap report (informational only)

`parity-check` also emits tier counts per spec §9.5:

- **Tier 1** — canonical feature with a non-empty `invariant` where the matching artifact row has `tests != "yes"`.
- **Tier 2** — cross-artifact `requires:` entries pointing at features missing from the referenced artifact.

Counts are reported but do **not** fail parity (report-only).

## Run

```bash
cd experiments/ae_rust_contract
cargo test
cargo run -p ae_cli_stub -- parity-check
```

**CI:** use `parity-check --strict` or `AE_PARITY_REQUIRE_SPEC=1` so a missing `spec/` fails (exit 2), not a silent skip (exit 0).

## Intentional cuts

No extractors, no MCP, no hub replication — only checks on **exported** samples.
