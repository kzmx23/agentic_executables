#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_DIR="${ROOT_DIR}/agentic_executables_cli"

normalize_os() {
  case "$1" in
    Darwin|darwin) echo "darwin" ;;
    Linux|linux) echo "linux" ;;
    *)
      echo "Unsupported OS: $1" >&2
      exit 1
      ;;
  esac
}

normalize_arch() {
  case "$1" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64) echo "x64" ;;
    *)
      echo "Unsupported architecture: $1" >&2
      exit 1
      ;;
  esac
}

if [[ -n "${AE_TARGET_TRIPLE:-}" ]]; then
  TARGET="${AE_TARGET_TRIPLE}"
else
  OS="$(normalize_os "$(uname -s)")"
  ARCH="$(normalize_arch "$(uname -m)")"
  TARGET="${OS}-${ARCH}"
fi

case "$TARGET" in
  darwin-arm64|darwin-x64|linux-x64)
    ;;
  *)
    echo "Unsupported target triple: $TARGET" >&2
    exit 1
    ;;
esac

VERSION="$(awk '/^version:/ {print $2; exit}' "${CLI_DIR}/pubspec.yaml")"
if [[ -z "$VERSION" ]]; then
  echo "Failed to detect CLI version from pubspec.yaml" >&2
  exit 1
fi

DIST_DIR="${ROOT_DIR}/dist/v${VERSION}"
TARGET_DIR="${DIST_DIR}/${TARGET}"
mkdir -p "$TARGET_DIR"

echo "Building ae for ${TARGET} (version v${VERSION})"
(
  cd "$CLI_DIR"
  HOME=/tmp DART_SUPPRESS_ANALYTICS=true dart compile exe bin/ae.dart -o "$TARGET_DIR/ae"
)

ARCHIVE="${DIST_DIR}/ae_${TARGET}.tar.gz"
SHA_FILE="${ARCHIVE}.sha256"

tar -C "$TARGET_DIR" -czf "$ARCHIVE" ae
shasum -a 256 "$ARCHIVE" > "$SHA_FILE"

echo "Created: $ARCHIVE"
echo "Created: $SHA_FILE"
