#!/usr/bin/env bash
# AE 3.0 — Claude Code on-project-open hook.
# Detects .ae_hub/ in the opened project and surfaces a hint.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

if [ -d "${PROJECT_DIR}/.ae_hub" ]; then
  cat <<EOF
AE 3.0: detected .ae_hub at ${PROJECT_DIR}/.ae_hub
Try: /ae-status                         (project-wide tier-classified gap report)
     /ae-distill <pack> <concept>       (delegate canonical distillation to a subagent)
EOF
fi
