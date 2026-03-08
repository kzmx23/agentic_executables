#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="${ROOT_DIR}/install.sh"
BUILD_SCRIPT="${ROOT_DIR}/scripts/build_release_artifacts.sh"

check_target() {
  local os="$1"
  local arch="$2"
  local expected="$3"

  local output
  output="$(AE_INSTALL_DRY_RUN=1 AE_INSTALL_OS="$os" AE_INSTALL_ARCH="$arch" "$INSTALL_SCRIPT")"
  echo "$output" | grep -q "target=${expected}"
}

check_target "Darwin" "arm64" "darwin-arm64"
check_target "Darwin" "x86_64" "darwin-x64"
check_target "Linux" "x86_64" "linux-x64"

"$BUILD_SCRIPT"

VERSION="$(awk '/^version:/ {print $2; exit}' "${ROOT_DIR}/agentic_executables_cli/pubspec.yaml")"
OS_RAW="$(uname -s)"
ARCH_RAW="$(uname -m)"

case "$OS_RAW" in
  Darwin) OS="darwin" ;;
  Linux) OS="linux" ;;
  *)
    echo "Unsupported local OS for smoke test: $OS_RAW" >&2
    exit 1
    ;;
esac

case "$ARCH_RAW" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64) ARCH="x64" ;;
  *)
    echo "Unsupported local arch for smoke test: $ARCH_RAW" >&2
    exit 1
    ;;
esac

TARGET="${OS}-${ARCH}"
BINARY_PATH="${ROOT_DIR}/dist/v${VERSION}/${TARGET}/ae"

if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Missing compiled binary: $BINARY_PATH" >&2
  exit 1
fi

"$BINARY_PATH" definition >/dev/null

echo "Installer smoke test passed for ${TARGET}."
