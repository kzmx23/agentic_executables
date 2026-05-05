---
title: "Hub layout"
outline: deep
---

# Hub layout

A hub is the unit of storage. Three hub kinds exist; the resolver walks them in a fixed order, and the kind determines what's allowed where. The full directory tree below is the contract — paths and filenames are stable across 3.0.x.

## Project hub

`<repo>/.ae_hub/` is the default and the only hub that holds artifacts. Project-private canonicals live here too; cross-project canonicals belong in the [user hub](#user-hub).

```text
.ae_hub/
  hub.yaml                            # config; reserves canonical_remotes for post-3.0 public hub
  canonical/
    <concept>/                        # live canonical (current major)
      matrix.yaml
      index.md
      meta.yaml                       # version: <int>; license; authors; sources; provenance
      CHANGELOG.md                    # human-readable history of in-place edits
      v1/                             # frozen snapshot — created ONLY at the v2 bump
        matrix.yaml
        index.md
        meta.yaml
        migration_to_v2.md            # optional, encouraged
  artifacts/
    local/<pack_name>/                # extracted from this repo
      meta.yaml                       # source path; file hashes; refs to canonical/; license; authors
      index.md                        # heuristic structural summary (or distilled if upgraded)
      matrix.yaml                     # cells filled in: which canonical features satisfied + status
      patterns.md                     # impl-specific idioms (only present if distilled)
      drift.yaml                      # written by `ae sync`; not by hand
    external/<pack_name>/             # extracted from URLs / PDFs / foreign repos
      ...same shape as local
    use/<library_id>/                 # ae_install/uninstall/update/use.md (yours or others')
      meta.yaml
      ae_install.md
      ae_uninstall.md
      ae_update.md
      ae_use.md
```

A few notes:

- `canonical/<concept>/` without a version subdirectory is the **live** version (current major). Snapshot subdirectories (`v1/`, `v2/`, …) appear only when you cut a breaking change with `ae canonical snapshot`. See [Authoring canonicals → Living vs snapshot](./authoring-canonicals#living-vs-snapshot).
- `artifacts/local/`, `artifacts/external/`, `artifacts/use/` partition the artifact namespace by `kind`. Extractors put their output in `local/`. Imported standards and PDFs land in `external/`. The `use/` partition holds AE Use install/uninstall/update/use instructions.
- `drift.yaml` is generated. Hand-edit only its `accepted:` section (see spec §8 for the contract).
- `patterns.md` only appears in artifacts that have been through distillation; heuristic-only artifacts skip it.

## User hub

`~/.ae_hub/` is the per-user hub. Its only purpose is canonicals reused across projects. No artifacts live here.

```text
~/.ae_hub/
  hub.yaml
  canonical/
    <concept>/                        # canonical you reuse across projects
```

If you author a canonical in one repo and want it in another, the simplest move today is `cp -r` into the user hub. A first-class `ae canonical promote` is fast-follow.

## Package hub (designed-for, manual in 3.0)

Packages can ship `<pkg>/.ae_hub/canonical/<concept>/` so installing the package gives you the canonical. The 3.0 resolver knows how to walk this layer; **auto-discovery is roadmapped to 3.x**. The supported flow today is manual:

```bash
ae canonical import --from path/to/pkg/.ae_hub/canonical/gltf_core --as gltf/core
```

`ae canonical import` copies the canonical into the project hub (or `--to <hub>`).

## Remote hub (reserved)

`hub.yaml.canonical_remotes` is the reserved field for the future public canonical hub. Nothing reads it in 3.0; it's there so 3.0 packs are publishable when the remote ships. See [Roadmap](./roadmap) for status.

## Resolution order

When something asks "where is canonical `gltf/core`?", AE walks:

1. **Project hub** — `<repo>/.ae_hub/canonical/gltf/core/`
2. **User hub** — `~/.ae_hub/canonical/gltf/core/`
3. **Package hub** — stub in 3.0; manual import is the live path
4. **Remote hub** — reserved

First hit wins. Artifacts are resolved at the **project hub only** — there's no shared-artifacts notion.

## What's reserved for 3.x

Three things in `hub.yaml` and the resolver are designed-for and inert in 3.0: `canonical_remotes`, package-hub auto-discovery, and the remote layer. Everything else listed above is live. See [Adapters](./adapters) for the resolver's port-and-adapter shape.
