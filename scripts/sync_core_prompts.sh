#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/prompts_framework"
TARGET_DIR="${ROOT_DIR}/agentic_executables_mcp/resources"
CORE_FILES=(ae_context.md ae_use.md ae_bootstrap.md)

usage() {
  echo "Usage: $0 [--check]" >&2
}

mode="sync"
if [[ $# -gt 1 ]]; then
  usage
  exit 2
fi
if [[ $# -eq 1 ]]; then
  case "$1" in
    --check)
      mode="check"
      ;;
    *)
      usage
      exit 2
      ;;
  esac
fi

status=0
for file in "${CORE_FILES[@]}"; do
  src="${SOURCE_DIR}/${file}"
  dst="${TARGET_DIR}/${file}"

  if [[ ! -f "$src" ]]; then
    echo "Missing source file: ${src}" >&2
    status=1
    continue
  fi

  if [[ "$mode" == "check" ]]; then
    if [[ ! -f "$dst" ]]; then
      echo "Missing target file: ${dst}" >&2
      status=1
      continue
    fi

    if ! cmp -s "$src" "$dst"; then
      echo "Drift detected: ${file}" >&2
      status=1
    fi
  else
    cp "$src" "$dst"
    echo "Synced ${file}"
  fi
done

if [[ "$mode" == "check" ]]; then
  if [[ $status -eq 0 ]]; then
    echo "Core prompts are in sync."
  else
    echo "Core prompt drift detected." >&2
  fi
fi

exit $status
