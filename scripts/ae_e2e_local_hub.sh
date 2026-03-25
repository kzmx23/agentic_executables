#!/usr/bin/env bash
# Local AE E2E: fresh hub, sharded know packs, matrix scaffold, optional Rust spec export.
# Usage:
#   ./scripts/ae_e2e_local_hub.sh reset     — remove .ae_hub, generated matrix, spec exports only
#   ./scripts/ae_e2e_local_hub.sh run       — reset + pub get + hub init + packs + matrix + export (default)
#   ./scripts/ae_e2e_local_hub.sh export    — export Rust spec only (expects populated .ae_hub)
# Env:
#   AE_E2E_NETWORK=1  — also run one URL know build (Flutter llms.txt); needs network.
#   AE_E2E_EXTENDED=1 — after a successful run, also smoke-test instructions/generate/verify/evaluate/package/doctor (see docs/ae_e2e_log.md).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

AE() { dart run agentic_executables_cli/bin/ae.dart "$@"; }

SPEC_DIR="$ROOT/experiments/ae_rust_contract/spec"

require_python3() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "ae_e2e: python3 is required for plan export (JSON → plan_ae_docs_know_design.md)" >&2
    exit 1
  fi
}

json_ok() {
  grep -q '"success":true' <<<"$1"
}

extended_verify() {
  echo "ae_e2e: extended smoke (instructions → generate → verify → evaluate → package → doctor)…"
  local o
  o=$(AE instructions --context library --action bootstrap --know ae_docs_know_design 2>&1) || {
    echo "$o" >&2
    return 1
  }
  json_ok "$o" || {
    echo "$o" >&2
    return 1
  }
  o=$(AE generate --library-id dart_e2e --library-root /tmp --engine template --dry-run --know ae_pkg_cli_readme 2>&1) || {
    echo "$o" >&2
    return 1
  }
  json_ok "$o" || {
    echo "$o" >&2
    return 1
  }
  o=$(AE verify --input "$ROOT/docs/ae_e2e_verify.json" 2>&1) || {
    echo "$o" >&2
    return 1
  }
  json_ok "$o" || {
    echo "$o" >&2
    return 1
  }
  o=$(AE evaluate --input "$ROOT/docs/ae_e2e_evaluate.json" 2>&1) || {
    echo "$o" >&2
    return 1
  }
  json_ok "$o" || {
    echo "$o" >&2
    return 1
  }
  o=$(AE package resolve --package dev.xs.registry --target linux --format json 2>&1) || {
    echo "$o" >&2
    return 1
  }
  local tmp
  tmp="$(mktemp)"
  echo "$o" >"$tmp"
  o=$(AE package validate --instructions "$tmp" 2>&1) || {
    rm -f "$tmp"
    echo "$o" >&2
    return 1
  }
  rm -f "$tmp"
  grep -q '^ok$' <<<"$o" || {
    echo "$o" >&2
    return 1
  }
  o=$(AE doctor 2>&1) || {
    echo "$o" >&2
    return 1
  }
  json_ok "$o" || {
    echo "$o" >&2
    return 1
  }
  echo "ae_e2e: extended smoke ok"
}

clean_spec_exports() {
  mkdir -p "$SPEC_DIR"
  find "$SPEC_DIR" -maxdepth 1 -type f ! -name '.gitkeep' -delete 2>/dev/null || true
}

reset_state() {
  rm -rf "$ROOT/.ae_hub"
  rm -f "$ROOT/docs/feature_matrix.yaml"
  clean_spec_exports
  touch "$SPEC_DIR/.gitkeep"
  echo "ae_e2e: reset (hub + docs/feature_matrix.yaml + spec exports cleared)"
}

run_pub_get() {
  (cd "$ROOT/agentic_executables_cli" && dart pub get)
}

init_hub() {
  AE hub init --project
}

build_packs() {
  local h="$ROOT/.ae_hub"
  AE know build --url "file://${ROOT}/docs/ae_know_design.md" --name ae_docs_know_design --hub "$h" --on-conflict update
  AE know build --path "${ROOT}/docs/error_code_playbook.md" --name ae_docs_error_codes --hub "$h" --on-conflict update
  AE know build --path "${ROOT}/docs_site/docs/know/index.md" --name ae_docs_site_know_index --hub "$h" --on-conflict update
  AE know build --path "${ROOT}/agentic_executables_cli/README.md" --name ae_pkg_cli_readme --hub "$h" --on-conflict update
  AE know build --path "${ROOT}/agentic_executables_mcp/README.md" --name ae_pkg_mcp_readme --hub "$h" --on-conflict update
  if [[ "${AE_E2E_NETWORK:-}" == "1" ]]; then
    AE know build --url "https://docs.flutter.dev/llms.txt" --name ae_url_smoke_flutter_llms --hub "$h" --on-conflict update
  fi
}

matrix_chain() {
  local h="$ROOT/.ae_hub"
  AE know matrix init --name ae_docs_know_design --columns cli,mcp,know,hub --title "AE E2E matrix" --hub "$h"
  AE know matrix scaffold --name ae_docs_know_design --repo "$ROOT" --hub "$h"
  AE know matrix diff --from-name ae_docs_know_design --to-file "$ROOT/docs/feature_matrix.yaml" --hub "$h" >/dev/null
  echo "ae_e2e: matrix scaffolded to docs/feature_matrix.yaml"
}

export_rust_spec() {
  require_python3
  local h="$ROOT/.ae_hub"
  mkdir -p "$SPEC_DIR"
  AE definition > "$SPEC_DIR/definition.json"
  AE know list --hub "$h" > "$SPEC_DIR/know_list.json"
  AE know show --name ae_docs_know_design --hub "$h" > "$SPEC_DIR/know_show_ae_docs_know_design.json"
  AE know plan --name ae_docs_know_design --hub "$h" > "$SPEC_DIR/know_plan_raw.json"
  python3 -c "
import json
p = '$SPEC_DIR/know_plan_raw.json'
d = json.load(open(p))
open('$SPEC_DIR/plan_ae_docs_know_design.md', 'w').write(d['data']['plan_markdown'])
"
  rm -f "$SPEC_DIR/know_plan_raw.json"
  cp "$ROOT/docs/feature_matrix.yaml" "$SPEC_DIR/feature_matrix.yaml"
  echo "ae_e2e: Rust spec exported to experiments/ae_rust_contract/spec/"
}

case "${1:-run}" in
  reset)
    reset_state
    ;;
  export)
    export_rust_spec
    ;;
  run|full)
    reset_state
    run_pub_get
    init_hub
    build_packs
    matrix_chain
    export_rust_spec
    if [[ "${AE_E2E_EXTENDED:-}" == "1" ]]; then
      extended_verify
    fi
    echo "ae_e2e: done. Run: cd experiments/ae_rust_contract && cargo test && cargo run -p ae_cli_stub -- parity-check"
    ;;
  *)
    echo "Usage: $0 [--] {run|reset|export}" >&2
    echo "  run   (default) — full reset + rebuild + export" >&2
    echo "  reset — wipe .ae_hub, feature_matrix.yaml, spec exports" >&2
    echo "  export — export Rust spec (requires existing hub)" >&2
    echo "Set AE_E2E_NETWORK=1 for optional URL smoke pack." >&2
    exit 1
    ;;
esac
