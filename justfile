# Local AE E2E (replaces removed scripts/ae_e2e_local_hub.sh).
# Requires: `just`, Dart; optional `cargo` for Rust parity.
# Env: AE_E2E_NETWORK=1 — URL smoke pack; AE_E2E_EXTENDED=1 — downstream smoke.

set shell := ['bash', '-uc']

repo := justfile_directory()
hub := repo / '.ae_hub'
spec_dir := repo / 'experiments' / 'ae_rust_contract' / 'spec'

default:
	@just --list

# Wipe hub, generated matrix, spec exports (keeps spec/.gitkeep).
e2e-reset:
	#!/usr/bin/env bash
	set -euo pipefail
	REPO="{{repo}}"
	SPEC="{{spec_dir}}"
	rm -rf "$REPO/.ae_hub"
	rm -f "$REPO/docs/feature_matrix.yaml"
	mkdir -p "$SPEC"
	find "$SPEC" -maxdepth 1 -type f ! -name '.gitkeep' -delete 2>/dev/null || true
	touch "$SPEC/.gitkeep"
	echo "ae_e2e: reset (hub + docs/feature_matrix.yaml + spec exports cleared)"

# Export Rust spec only; requires existing `.ae_hub`.
e2e-export:
	#!/usr/bin/env bash
	set -euo pipefail
	REPO="{{repo}}"
	HUB="$REPO/.ae_hub"
	SPEC="{{spec_dir}}"
	mkdir -p "$SPEC"
	cd "$REPO"
	dart run agentic_executables_cli/bin/ae.dart definition > "$SPEC/definition.json"
	dart run agentic_executables_cli/bin/ae.dart know list --hub "$HUB" > "$SPEC/know_list.json"
	dart run agentic_executables_cli/bin/ae.dart know show --name ae_docs_know_design --hub "$HUB" > "$SPEC/know_show_ae_docs_know_design.json"
	dart run agentic_executables_cli/bin/ae.dart know plan --name ae_docs_know_design --hub "$HUB" --out "$SPEC/plan_ae_docs_know_design.md"
	cp "$REPO/docs/feature_matrix.yaml" "$SPEC/feature_matrix.yaml"
	echo "ae_e2e: Rust spec exported to experiments/ae_rust_contract/spec/"

# Full pipeline: reset, pub get, hub, packs, matrix, export, optional extended smoke.
e2e:
	#!/usr/bin/env bash
	set -euo pipefail
	REPO="{{repo}}"
	HUB="$REPO/.ae_hub"
	SPEC="{{spec_dir}}"
	just e2e-reset
	( cd "$REPO/agentic_executables_cli" && dart pub get )
	cd "$REPO"
	dart run agentic_executables_cli/bin/ae.dart hub init --project
	dart run agentic_executables_cli/bin/ae.dart know build --url "file://$REPO/docs/ae_know_design.md" --name ae_docs_know_design --hub "$HUB" --on-conflict update
	dart run agentic_executables_cli/bin/ae.dart know build --path "$REPO/docs/error_code_playbook.md" --name ae_docs_error_codes --hub "$HUB" --on-conflict update
	dart run agentic_executables_cli/bin/ae.dart know build --path "$REPO/docs_site/docs/know/index.md" --name ae_docs_site_know_index --hub "$HUB" --on-conflict update
	dart run agentic_executables_cli/bin/ae.dart know build --path "$REPO/agentic_executables_cli/README.md" --name ae_pkg_cli_readme --hub "$HUB" --on-conflict update
	dart run agentic_executables_cli/bin/ae.dart know build --path "$REPO/agentic_executables_mcp/README.md" --name ae_pkg_mcp_readme --hub "$HUB" --on-conflict update
	if [[ "${AE_E2E_NETWORK:-}" == "1" ]]; then
	  dart run agentic_executables_cli/bin/ae.dart know build --url "https://docs.flutter.dev/llms.txt" --name ae_url_smoke_flutter_llms --hub "$HUB" --on-conflict update
	fi
	dart run agentic_executables_cli/bin/ae.dart know matrix init --name ae_docs_know_design --columns cli,mcp,know,hub --title "AE E2E matrix" --hub "$HUB"
	dart run agentic_executables_cli/bin/ae.dart know matrix scaffold --name ae_docs_know_design --repo "$REPO" --hub "$HUB"
	dart run agentic_executables_cli/bin/ae.dart know matrix diff --from-name ae_docs_know_design --to-file "$REPO/docs/feature_matrix.yaml" --hub "$HUB" >/dev/null
	echo "ae_e2e: matrix scaffolded to docs/feature_matrix.yaml"
	mkdir -p "$SPEC"
	dart run agentic_executables_cli/bin/ae.dart definition > "$SPEC/definition.json"
	dart run agentic_executables_cli/bin/ae.dart know list --hub "$HUB" > "$SPEC/know_list.json"
	dart run agentic_executables_cli/bin/ae.dart know show --name ae_docs_know_design --hub "$HUB" > "$SPEC/know_show_ae_docs_know_design.json"
	dart run agentic_executables_cli/bin/ae.dart know plan --name ae_docs_know_design --hub "$HUB" --out "$SPEC/plan_ae_docs_know_design.md"
	cp "$REPO/docs/feature_matrix.yaml" "$SPEC/feature_matrix.yaml"
	echo "ae_e2e: Rust spec exported to experiments/ae_rust_contract/spec/"
	if [[ "${AE_E2E_EXTENDED:-}" == "1" ]]; then
	  o=$(dart run agentic_executables_cli/bin/ae.dart instructions --context library --action bootstrap --know ae_docs_know_design 2>&1) || { echo "$o" >&2; exit 1; }
	  echo "$o" | grep -q '"success":true' || { echo "$o" >&2; exit 1; }
	  o=$(dart run agentic_executables_cli/bin/ae.dart generate --library-id dart_e2e --library-root /tmp --engine template --dry-run --know ae_pkg_cli_readme 2>&1) || { echo "$o" >&2; exit 1; }
	  echo "$o" | grep -q '"success":true' || { echo "$o" >&2; exit 1; }
	  o=$(dart run agentic_executables_cli/bin/ae.dart verify --input "$REPO/docs/ae_e2e_verify.json" 2>&1) || { echo "$o" >&2; exit 1; }
	  echo "$o" | grep -q '"success":true' || { echo "$o" >&2; exit 1; }
	  o=$(dart run agentic_executables_cli/bin/ae.dart evaluate --input "$REPO/docs/ae_e2e_evaluate.json" 2>&1) || { echo "$o" >&2; exit 1; }
	  echo "$o" | grep -q '"success":true' || { echo "$o" >&2; exit 1; }
	  o=$(dart run agentic_executables_cli/bin/ae.dart package resolve --package dev.xs.registry --target linux --format json 2>&1) || { echo "$o" >&2; exit 1; }
	  tmp=$(mktemp)
	  echo "$o" >"$tmp"
	  o=$(dart run agentic_executables_cli/bin/ae.dart package validate --instructions "$tmp" 2>&1) || { rm -f "$tmp"; echo "$o" >&2; exit 1; }
	  rm -f "$tmp"
	  grep -q '^ok$' <<<"$o" || { echo "$o" >&2; exit 1; }
	  o=$(dart run agentic_executables_cli/bin/ae.dart doctor 2>&1) || { echo "$o" >&2; exit 1; }
	  echo "$o" | grep -q '"success":true' || { echo "$o" >&2; exit 1; }
	  echo "ae_e2e: extended smoke ok"
	fi
	echo "ae_e2e: done. Run: cd experiments/ae_rust_contract && cargo test && cargo run -p ae_cli_stub -- parity-check"
