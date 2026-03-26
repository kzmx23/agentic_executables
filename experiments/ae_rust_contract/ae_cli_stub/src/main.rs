//! Minimal contract check: serde against exported `ae` JSON/YAML only.
//! Not a CLI port. **Do not grow this crate** — contracts come from know packs + `ae spec export`.
//! Prefer deleting code here over adding features; parity is how far JSON shapes alone carry.

use serde_json::Value;
use serde_yaml::Value as YamlValue;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

fn spec_dir() -> PathBuf {
    let mut dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    dir.pop();
    dir.join("spec")
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() > 1 && args[1] == "parity-check" {
        let strict = args.iter().any(|a| a == "--strict")
            || env::var("AE_PARITY_REQUIRE_SPEC").ok().as_deref() == Some("1");
        std::process::exit(parity_check(strict));
    }
    eprintln!("ae_cli_stub — JSON/YAML contract check (not a second CLI)");
    eprintln!("Usage: cargo run -p ae_cli_stub -- parity-check [--strict]");
    eprintln!("  --strict or AE_PARITY_REQUIRE_SPEC=1 : exit 2 if spec/ missing (CI)");
    std::process::exit(1);
}

fn spec_ready(root: &std::path::Path) -> bool {
    root.join("spec_index.json").is_file()
        && root.join("definition.json").is_file()
        && root.join("definition.yaml").is_file()
}

/// Returns exit code: 0 ok, 2 missing spec in strict mode, 101 on assert/panic.
fn parity_check(strict: bool) -> i32 {
    let root = spec_dir();
    if !spec_ready(&root) {
        eprintln!(
            "parity-check: skipped (spec/ empty or missing spec_index.json). Run: just e2e"
        );
        if strict {
            eprintln!("parity-check: strict mode requires spec; failing.");
            return 2;
        }
        return 0;
    }

    let def_ptr: Value = serde_json::from_str(
        &fs::read_to_string(root.join("definition.json")).expect("definition.json"),
    )
    .expect("definition.json pointer");
    assert_eq!(
        def_ptr.get("schema").and_then(|v| v.as_str()),
        Some("ae.spec_definition_ptr.v1")
    );
    let def_yaml_raw = fs::read_to_string(root.join("definition.yaml")).expect("definition.yaml");
    let def_yaml: YamlValue = serde_yaml::from_str(&def_yaml_raw).expect("definition.yaml parse");
    assert_eq!(
        def_yaml.get("schema").and_then(|v| v.as_str()),
        Some("ae.definition.v1")
    );
    assert_eq!(def_yaml.get("version").and_then(|v| v.as_u64()), Some(1));
    let def_md = fs::read_to_string(root.join("definition.md")).expect("definition.md");
    assert!(!def_md.is_empty(), "definition.md non-empty");

    let list: Value = serde_json::from_str(
        &fs::read_to_string(root.join("know_list.json")).expect("know_list.json"),
    )
    .expect("know_list json");
    assert_eq!(list.get("success").and_then(|v| v.as_bool()), Some(true));
    let packs = list
        .pointer("/data/packs")
        .and_then(|p| p.as_array())
        .expect("know_list.data.packs");
    assert!(!packs.is_empty(), "know_list.data.packs non-empty");

    let index: Value = serde_json::from_str(
        &fs::read_to_string(root.join("spec_index.json")).expect("spec_index.json"),
    )
    .expect("spec_index json");
    assert_eq!(
        index.get("schema").and_then(|v| v.as_str()),
        Some("spec_export.v2")
    );
    assert_eq!(index.get("version").and_then(|v| v.as_u64()), Some(2));
    assert_eq!(
        index.get("export_base").and_then(|v| v.as_str()),
        Some(".")
    );
    assert!(
        index
            .get("locale")
            .and_then(|v| v.as_str())
            .map_or(false, |s| !s.is_empty()),
        "spec_index.locale"
    );

    let index_packs = index
        .get("packs")
        .and_then(|p| p.as_array())
        .expect("spec_index.packs");
    assert_eq!(
        index_packs.len(),
        packs.len(),
        "spec_index.packs len vs know_list pack count"
    );

    if let Some(md) = index.get("matrix_diff").and_then(|v| v.as_str()) {
        let raw = fs::read_to_string(root.join(md)).expect("matrix_diff.json");
        let diff: Value = serde_json::from_str(&raw).expect("matrix_diff json");
        assert!(diff.get("summary").is_some(), "matrix_diff.summary");
    }

    for p in index_packs {
        let name = p.get("name").and_then(|v| v.as_str()).expect("pack.name");
        let ks = p
            .get("know_show")
            .and_then(|v| v.as_str())
            .expect("pack.know_show");
        let pl = p.get("plan").and_then(|v| v.as_str()).expect("pack.plan");

        let show: Value = serde_json::from_str(
            &fs::read_to_string(root.join(ks))
                .unwrap_or_else(|_| panic!("read know_show {ks} for {name}")),
        )
        .expect("know_show json");
        assert_eq!(show.get("success").and_then(|v| v.as_bool()), Some(true));
        let content = show
            .pointer("/data/content")
            .and_then(|v| v.as_str())
            .expect("know_show.data.content");
        assert!(!content.is_empty(), "know_show content for {name}");
        if let Some(pth) = show
            .pointer("/data/meta/source/path")
            .and_then(|v| v.as_str())
        {
            assert!(
                !Path::new(pth).is_absolute(),
                "know_show meta.source.path should be relative (export from repo root), got {pth}"
            );
        }

        let plan = fs::read_to_string(root.join(pl))
            .unwrap_or_else(|_| panic!("read plan {pl} for {name}"));
        assert!(!plan.is_empty(), "plan md for {name}");
    }

    let matrix_yaml = fs::read_to_string(root.join("feature_matrix.yaml")).expect("matrix yaml");
    let matrix: YamlValue = serde_yaml::from_str(&matrix_yaml).expect("matrix yaml parse");
    assert_eq!(
        matrix.get("version").and_then(|v| v.as_u64()),
        Some(1),
        "matrix.version"
    );
    assert_eq!(
        matrix.get("schema").and_then(|v| v.as_str()),
        Some("ae.know.matrix.v1")
    );
    let title = matrix
        .get("title")
        .and_then(|v| v.as_str())
        .expect("matrix.title");
    assert!(!title.is_empty());

    let loc = index
        .get("locale")
        .and_then(|v| v.as_str())
        .unwrap_or("?");
    println!(
        "parity-check: ok (definition.yaml/md, know list, {} packs, feature_matrix.yaml, locale={})",
        index_packs.len(),
        loc
    );
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parity_fixtures_parse() {
        let root = spec_dir();
        if !spec_ready(&root) {
            eprintln!("skip: populate experiments/ae_rust_contract/spec via `just e2e`");
            return;
        }
        assert_eq!(parity_check(false), 0);
    }
}
