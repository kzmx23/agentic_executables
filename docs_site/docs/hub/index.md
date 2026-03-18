---
title: Hub
outline: deep
---

# Hub

The hub is a local-first directory that stores three types of artifacts:

- **know/** — distilled domain knowledge from specs, docs, and repos
- **use/** — lifecycle files (install, uninstall, update, use)
- **packages/** — deterministic deployment instructions

## Why local-first

Everything works offline. Remote registries are optional pull/push targets. The resolution chain is: project hub → user hub → remote.

## Initialize a hub

### User-level hub (shared across projects)

```bash
ae hub init
```

### Project-level hub

```bash
ae hub init --project
```

Expected result: directory created at `~/.ae_hub/` or `./.ae_hub/` with `hub.yaml`, `know/`, `use/`, `packages/` subdirectories.

### Custom path

```bash
ae hub init --path /path/to/my-hub
```

## Check hub status

```bash
ae hub status
```

Expected result: JSON with hub path, artifact counts, and remote configuration.

Human-readable:

```bash
ae hub status --human
```

## Hub structure

```text
.ae_hub/
├── hub.yaml         # Remote config and defaults
├── know/            # Knowledge packs (ae know build)
│   └── mcp/
│       ├── index.md
│       └── meta.yaml
├── use/             # Lifecycle files (ae registry get)
│   └── dart_mcp/
│       ├── ae_install.md
│       ├── ae_uninstall.md
│       ├── ae_update.md
│       └── ae_use.md
└── packages/        # Deployment instructions (optional)
```

## Sync with remote

### Pull a project from remote registry

```bash
ae hub pull --library-id python_requests
```

Downloads all ae_use files for that project into the local hub's `use/` directory.

### Push local artifacts

```bash
ae hub push
```

Generates instructions for contributing local artifacts back to the remote registry.

### Configure remotes

Edit `hub.yaml`:

```yaml
version: 1
remotes:
  origin:
    url: "https://github.com/fluent-meaning-symbiotic/agentic_executables_registry"
    branch: "main"
    type: "github"
```

## Resolution chain

When any command needs an artifact:

1. **Project hub** (`./.ae_hub/`) — highest priority
2. **User hub** (`~/.ae_hub/`) — shared across all projects
3. **Remote** — fetched on demand only

## Common failure modes

### `hub_not_found`

Cause: no hub at project or user level.

Recovery:

```bash
ae hub init
```

### `hub_init_failed`

Cause: permission issue or invalid path.

Recovery: check filesystem permissions, then retry with explicit `--path`.

## What to do next

- [Extract domain knowledge](/know/) with `ae know build`
- [Run workflows](/use/) with hub-backed artifacts
