//! Minimal contract check: serde against exported `ae spec export` JSON/YAML only.
//! Not a CLI port. **Do not grow this crate** — contracts come from the Dart core;
//! this crate validates that spec_export.v3 crosses the JSON wire without drift.

use serde_json::Value;
use serde_yaml::Value as YamlValue;
use std::env;
use std::fs;
use std::path::PathBuf;

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
            "parity-check: skipped (spec/ empty or missing spec_index.json). Run: ae spec export --out experiments/ae_rust_contract/spec"
        );
        if strict {
            eprintln!("parity-check: strict mode requires spec; failing.");
            return 2;
        }
        return 0;
    }

    // definition.* trio — unchanged v2 shape.
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

    // spec_index.json — v3 shape.
    let index: Value = serde_json::from_str(
        &fs::read_to_string(root.join("spec_index.json")).expect("spec_index.json"),
    )
    .expect("spec_index json");
    assert_eq!(
        index.get("schema").and_then(|v| v.as_str()),
        Some("spec_export.v3")
    );
    assert_eq!(index.get("version").and_then(|v| v.as_u64()), Some(3));
    assert_eq!(
        index.get("export_base").and_then(|v| v.as_str()),
        Some(".")
    );
    let locale = index
        .get("locale")
        .and_then(|v| v.as_str())
        .expect("spec_index.locale");
    assert!(!locale.is_empty(), "spec_index.locale non-empty");

    let canonicals = index
        .get("canonicals")
        .and_then(|v| v.as_array())
        .expect("spec_index.canonicals");
    let artifacts = index
        .get("artifacts")
        .and_then(|v| v.as_array())
        .expect("spec_index.artifacts");

    // Canonical pack files.
    let mut canonical_matrices: Vec<Value> = Vec::with_capacity(canonicals.len());
    for c in canonicals {
        let concept = c
            .get("concept")
            .and_then(|v| v.as_str())
            .expect("canonical.concept");
        let file = c
            .get("file")
            .and_then(|v| v.as_str())
            .expect("canonical.file");
        let body: Value = serde_json::from_str(
            &fs::read_to_string(root.join(file))
                .unwrap_or_else(|_| panic!("read canonical file {file} for {concept}")),
        )
        .unwrap_or_else(|_| panic!("parse canonical file {file} for {concept}"));
        assert_eq!(
            body.get("schema").and_then(|v| v.as_str()),
            Some("ae.canonical.v3"),
            "{file} schema"
        );
        assert_eq!(
            body.pointer("/meta/schema").and_then(|v| v.as_str()),
            Some("ae.canonical.meta.v1"),
            "{file} meta.schema"
        );
        assert_eq!(
            body.pointer("/matrix/schema").and_then(|v| v.as_str()),
            Some("ae.canonical_matrix.v1"),
            "{file} matrix.schema"
        );
        let feats = body
            .pointer("/matrix/features")
            .and_then(|v| v.as_array())
            .unwrap_or_else(|| panic!("{file} matrix.features array"));
        assert!(!feats.is_empty(), "{file} matrix.features non-empty");
        canonical_matrices.push(body.get("matrix").cloned().expect("matrix"));
    }

    // Artifact pack files.
    let mut artifact_bodies: Vec<Value> = Vec::with_capacity(artifacts.len());
    for a in artifacts {
        let name = a.get("name").and_then(|v| v.as_str()).expect("artifact.name");
        let file = a
            .get("file")
            .and_then(|v| v.as_str())
            .expect("artifact.file");
        let body: Value = serde_json::from_str(
            &fs::read_to_string(root.join(file))
                .unwrap_or_else(|_| panic!("read artifact file {file} for {name}")),
        )
        .unwrap_or_else(|_| panic!("parse artifact file {file} for {name}"));
        assert_eq!(
            body.get("schema").and_then(|v| v.as_str()),
            Some("ae.artifact.v3"),
            "{file} schema"
        );
        assert_eq!(
            body.pointer("/meta/schema").and_then(|v| v.as_str()),
            Some("ae.artifact.meta.v1"),
            "{file} meta.schema"
        );
        assert_eq!(
            body.pointer("/matrix/schema").and_then(|v| v.as_str()),
            Some("ae.artifact_matrix.v1"),
            "{file} matrix.schema"
        );
        artifact_bodies.push(body);
    }

    // Collect artifact names from the index in the same order as artifact_bodies.
    let artifact_names: Vec<String> = artifacts
        .iter()
        .map(|a| {
            a.get("name")
                .and_then(|v| v.as_str())
                .unwrap_or("<unknown>")
                .to_string()
        })
        .collect();

    // Gap report — informational only per spec §9.5; does not fail parity.
    let (tier1, tier2) = report_gaps(&canonical_matrices, &artifact_bodies, &artifact_names);

    println!(
        "parity-check: ok (definition trio, {} canonical(s), {} artifact(s), locale={}, tier1_gaps={}, tier2_gaps={})",
        canonicals.len(),
        artifacts.len(),
        locale,
        tier1,
        tier2,
    );
    0
}

/// Tier 1 = canonical features with non-empty `invariant` where the matching
/// artifact row has `tests != "yes"`.
/// Tier 2 = cross-artifact `requires:` entries pointing at features missing
/// from the referenced artifact.
///
/// Returns (tier1_count, tier2_count). Also prints a one-line-per-gap summary.
fn report_gaps(
    canonical_matrices: &[Value],
    artifact_bodies: &[Value],
    artifact_names: &[String],
) -> (usize, usize) {
    let mut tier1 = 0usize;
    let mut tier2 = 0usize;

    // Build concept -> (feature_id -> invariant-non-empty?) map.
    let mut concept_invariants: std::collections::HashMap<String, std::collections::HashMap<String, bool>> =
        std::collections::HashMap::new();
    for m in canonical_matrices {
        let concept = m
            .get("concept")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        if concept.is_empty() {
            continue;
        }
        let feats = m
            .get("features")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        let mut map = std::collections::HashMap::new();
        for f in feats {
            let id = f
                .get("id")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            if id.is_empty() {
                continue;
            }
            let inv = f
                .get("invariant")
                .and_then(|v| v.as_str())
                .map(|s| !s.is_empty())
                .unwrap_or(false);
            map.insert(id, inv);
        }
        concept_invariants.insert(concept, map);
    }

    // Tier 1: canonical feature has invariant text + artifact row tests != "yes".
    for body in artifact_bodies {
        let feats = body
            .pointer("/matrix/features")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        for f in feats {
            let fid = f.get("id").and_then(|v| v.as_str()).unwrap_or("");
            let concept = f.get("canonical").and_then(|v| v.as_str()).unwrap_or("");
            if fid.is_empty() || concept.is_empty() {
                continue;
            }
            let inv = concept_invariants
                .get(concept)
                .and_then(|m| m.get(fid))
                .copied()
                .unwrap_or(false);
            if !inv {
                continue;
            }
            let tests = f.get("tests").and_then(|v| v.as_str()).unwrap_or("");
            if tests != "yes" {
                tier1 += 1;
                eprintln!(
                    "  tier1: {concept}::{fid} — invariant present, tests={}",
                    if tests.is_empty() { "<none>" } else { tests }
                );
            }
        }
    }

    // Tier 2: cross-artifact requires:. Build artifact_name -> set of (canonical, feature_id).
    let mut artifact_feature_ids: std::collections::HashMap<String, std::collections::HashSet<(String, String)>> =
        std::collections::HashMap::new();
    for (i, body) in artifact_bodies.iter().enumerate() {
        let name = artifact_names
            .get(i)
            .cloned()
            .unwrap_or_else(|| "<unknown>".to_string());
        let feats = body
            .pointer("/matrix/features")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        let mut set = std::collections::HashSet::new();
        for f in feats {
            let fid = f.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
            let concept = f
                .get("canonical")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            if !fid.is_empty() && !concept.is_empty() {
                set.insert((concept, fid));
            }
        }
        artifact_feature_ids.insert(name, set);
    }

    for body in artifact_bodies {
        let Some(reqs) = body.pointer("/requires").and_then(|v| v.as_array()) else {
            continue;
        };
        for req in reqs {
            let target = req.get("artifact").and_then(|v| v.as_str()).unwrap_or("");
            let concept = req.get("canonical").and_then(|v| v.as_str()).unwrap_or("");
            let feats = req
                .get("features")
                .and_then(|v| v.as_array())
                .cloned()
                .unwrap_or_default();
            if target.is_empty() || concept.is_empty() {
                continue;
            }
            let target_ids = artifact_feature_ids
                .get(target)
                .cloned()
                .unwrap_or_default();
            for fv in feats {
                let fid = fv.as_str().unwrap_or("").to_string();
                if fid.is_empty() {
                    continue;
                }
                if !target_ids.contains(&(concept.to_string(), fid.clone())) {
                    tier2 += 1;
                    eprintln!(
                        "  tier2: requires {target}::{concept}::{fid} missing from target artifact"
                    );
                }
            }
        }
    }

    (tier1, tier2)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parity_fixtures_parse() {
        let root = spec_dir();
        if !spec_ready(&root) {
            eprintln!("skip: populate experiments/ae_rust_contract/spec via `ae spec export`");
            return;
        }
        assert_eq!(parity_check(false), 0);
    }
}
