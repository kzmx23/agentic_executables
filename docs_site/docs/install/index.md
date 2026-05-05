---
title: Install and Verify
outline: deep
---

# Install and Verify

## Purpose

Install the `ae` CLI and confirm it runs so every later workflow starts from a known-good binary.

This page is optimized for install success first, then immediate verification.

## Prerequisites

- Terminal access
- `curl`
- Ability to write to `~/.local/bin` (default install location)

## macOS and Linux (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/fluent-meaning-symbiotic/agentic_executables/main/install.sh | bash
```

### Verify install

```bash
ae definition
```

Expected output:

- Successful command execution with AE definition metadata.

## Install options

Pin version:

```bash
AE_INSTALL_VERSION=v3.0.0 curl -fsSL https://raw.githubusercontent.com/fluent-meaning-symbiotic/agentic_executables/main/install.sh | bash
```

Dry run:

```bash
AE_INSTALL_DRY_RUN=1 curl -fsSL https://raw.githubusercontent.com/fluent-meaning-symbiotic/agentic_executables/main/install.sh | bash
```

Custom bin directory:

```bash
AE_INSTALL_BIN_DIR="$HOME/bin" curl -fsSL https://raw.githubusercontent.com/fluent-meaning-symbiotic/agentic_executables/main/install.sh | bash
```

## Common failure modes

### Command not found after install

Cause:

- `BIN_DIR` is not in `PATH`.

Recovery:

```bash
export PATH="$HOME/.local/bin:$PATH"
ae definition
```

### Unsupported target

Cause:

- Platform is not currently published (`darwin-arm64`, `darwin-x64`, `linux-x64` only).

Recovery:

- Build from source using project README instructions.

### Archive missing binary

Cause:

- Corrupt download or release packaging mismatch.

Recovery:

- Retry install, then inspect release artifacts and checksums.

## Verify

`ae definition` completes successfully after install (see [Verify install](#verify-install)).

## If it fails

Use the **Common failure modes** sections above, then [Troubleshooting](/troubleshooting/) and the [AE Error Code Playbook](https://github.com/fluent-meaning-symbiotic/agentic_executables/blob/main/docs/error_code_playbook.md).

## What to run next

- `ae doctor`
- `ae instructions --context library --action bootstrap`

For structured error recovery, see:

- [Troubleshooting](/troubleshooting/)
- [AE Error Code Playbook](https://github.com/fluent-meaning-symbiotic/agentic_executables/blob/main/docs/error_code_playbook.md)
