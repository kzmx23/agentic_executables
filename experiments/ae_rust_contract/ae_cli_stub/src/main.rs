//! Stub CLI: load exported `ae` JSON/YAML fixtures and verify serde shapes.
//! Intentional cuts: no hub IO, no extractors, no MCP.

use serde::Deserialize;
use serde_json::Value;
use std::env;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Deserialize)]
struct DefinitionEnvelope {
    success: bool,
    #[serde(default)]
    data: Option<Value>,
}

#[derive(Debug, Deserialize)]
struct KnowListEnvelope {
    success: bool,
    data: Option<KnowListData>,
}

#[derive(Debug, Deserialize)]
struct KnowListData {
    packs: Vec<Value>,
    #[allow(dead_code)]
    count: Option<u32>,
}

#[derive(Debug, Deserialize)]
struct KnowShowEnvelope {
    success: bool,
    data: Option<KnowShowData>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct KnowShowData {
    name: String,
    meta: Value,
    content: String,
}

#[derive(Debug, Deserialize)]
struct FeatureMatrixFile {
    version: u32,
    schema: String,
    title: String,
}

fn spec_dir() -> PathBuf {
    let mut dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    dir.pop();
    dir.join("spec")
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() > 1 && args[1] == "parity-check" {
        parity_check();
        return;
    }
    eprintln!("ae_stub — AE Rust experiment stub");
    eprintln!("Usage: ae_stub parity-check");
    std::process::exit(1);
}

fn spec_ready(root: &std::path::Path) -> bool {
    root.join("definition.json").is_file()
}

fn parity_check() {
    let root = spec_dir();
    if !spec_ready(&root) {
        eprintln!(
            "parity-check: skipped (spec/ empty). Run from repo root: just e2e"
        );
        return;
    }
    let def: DefinitionEnvelope = serde_json::from_str(
        &fs::read_to_string(root.join("definition.json")).expect("definition.json"),
    )
    .expect("definition envelope");
    assert!(def.success, "definition.success");
    assert!(def.data.is_some(), "definition.data");

    let list: KnowListEnvelope = serde_json::from_str(
        &fs::read_to_string(root.join("know_list.json")).expect("know_list.json"),
    )
    .expect("know_list envelope");
    assert!(list.success);
    let packs = list.data.as_ref().expect("know_list.data").packs.len();
    assert!(packs > 0, "expected non-empty hub list");

    let show: KnowShowEnvelope = serde_json::from_str(
        &fs::read_to_string(root.join("know_show_ae_docs_know_design.json"))
            .expect("know_show json"),
    )
    .expect("know_show envelope");
    assert!(show.success);
    let d = show.data.expect("know_show.data");
    assert!(!d.content.is_empty());

    let matrix_yaml = fs::read_to_string(root.join("feature_matrix.yaml")).expect("matrix yaml");
    let matrix: FeatureMatrixFile = serde_yaml::from_str(&matrix_yaml).expect("matrix yaml parse");
    assert_eq!(matrix.version, 1);
    assert_eq!(matrix.schema, "ae.know.matrix.v1");
    assert!(!matrix.title.is_empty());

    println!("parity-check: ok (definition, know list/show, feature_matrix.yaml)");
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
        parity_check();
    }
}
