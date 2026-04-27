---
title: "Quick start"
outline: deep
---

# Quick start

This walkthrough takes you from a fresh checkout of any Dart, Rust, or Kotlin/Swift repo to a tier-classified gap report in about a minute. No model is invoked. No network. Heuristic extraction handles step 1, drift detection handles step 4.

If you haven't installed the `ae` binary yet, see the existing [Install guide](/install/) — 3.0 ships through the same channel as 2.x.

## 1. Initialize the hub

`ae init` creates `.ae_hub/` if needed, walks the project recursively for known manifests (`pubspec.yaml`, `Cargo.toml`, `Package.swift`, `build.gradle.kts`), and dispatches each sub-package to the matching [heuristic extractor](./adapters). One artifact pack lands per package.

```bash
$ cd ~/code/my_engine
$ ae init
ae 3.0 init: scanning my_engine
  + dart    core_packages/ecs            → artifacts/local/dart_ecs
  + dart    core_packages/render3d       → artifacts/local/dart_render3d
  + rust    core_packages/physics        → artifacts/local/rust_physics
  + kotlin  bridges/android              → artifacts/local/kotlin_android_bridge
  + swift   bridges/ios                  → artifacts/local/swift_ios_bridge
ingested 5 artifacts in 0.42s
```

No canonicals exist yet; the artifacts have empty matrices and unresolved `references_canonical` lists. That's fine.

## 2. See the gaps

`ae status` prints the tier-classified cockpit. Tier 4 — unreferenced canonicals — dominates a fresh hub because nothing has been linked yet.

```text
$ ae status
AE 3.0 — my_engine

Tier 1  INVARIANT VIOLATIONS              0
Tier 2  UPSTREAM BLOCKERS                 0
Tier 3  PARTIAL FEATURES                  0
Tier 4  UNREFERENCED CANONICALS           0   (no canonicals authored yet)

5 artifacts, 0 canonicals.  Run `ae canonical init --concept <slug>` to author one.
```

## 3. Author or link a canonical

Either author a canonical from scratch (`ae canonical init --concept ecs --title "ECS"` and edit by hand — see [Authoring canonicals](./authoring-canonicals)) or link an existing one. Linking adds the canonical to an artifact's `references_canonical:` list and materializes one matrix row per canonical feature with `impl: missing` as the default cell.

```bash
$ ae canonical init --concept ecs --title "Entity-Component-System"
created canonical/ecs/ (live; meta.yaml, matrix.yaml, index.md scaffolded)

$ # ...edit canonical/ecs/matrix.yaml to declare ~10–50 features...

$ ae artifact link --pack dart_ecs --canonical ecs
linked dart_ecs → ecs (live)
materialized 12 matrix rows (impl: missing)
```

## 4. Re-run status — now with real signal

After linking, `ae status` has something to compare. The gap report classifies the work ahead.

```text
$ ae status
AE 3.0 — my_engine

Tier 1  INVARIANT VIOLATIONS              2
  ecs/system.tick                "Tick is monotonically increasing"
                                  → no test asserts this   (dart_ecs)
  ecs/entity.create              "Handles are non-reusable within a session."
                                  → no test asserts this   (dart_ecs)

Tier 2  UPSTREAM BLOCKERS                 0

Tier 3  PARTIAL FEATURES                  3
  dart_ecs                       3 features at impl=partial
                                 (system.tick, world.tick, query.basic)

Tier 4  UNREFERENCED CANONICALS           0

5 artifacts, 1 canonical.  Use `ae status --pack <name>` to drill in.
```

That's the loop. From here you fill in test coverage to clear Tier 1, finish partial features to clear Tier 3, author more canonicals, and let `ae sync` keep the file hashes honest as the source evolves.

## Where to next

- [Hub layout](./hub-layout) — what's in `.ae_hub/` and why.
- [CLI reference](./cli-reference) — every command and its options.
- [Walkthroughs](./walkthroughs) — three realistic scenarios end-to-end.
