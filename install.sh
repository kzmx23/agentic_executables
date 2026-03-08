#!/usr/bin/env bash
set -euo pipefail

REPO="fluent-meaning-symbiotic/agentic_executables"
BINARY_NAME="ae"

OS_RAW="${AE_INSTALL_OS:-$(uname -s)}"
ARCH_RAW="${AE_INSTALL_ARCH:-$(uname -m)}"
VERSION="${AE_INSTALL_VERSION:-latest}"
BASE_URL="${AE_INSTALL_BASE_URL:-https://github.com/${REPO}/releases}"
BIN_DIR="${AE_INSTALL_BIN_DIR:-${HOME}/.local/bin}"
DRY_RUN="${AE_INSTALL_DRY_RUN:-0}"

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

OS="$(normalize_os "$OS_RAW")"
ARCH="$(normalize_arch "$ARCH_RAW")"
TARGET="${OS}-${ARCH}"

case "$TARGET" in
  darwin-arm64|darwin-x64|linux-x64)
    ;;
  *)
    echo "Unsupported target: $TARGET" >&2
    exit 1
    ;;
esac

ARCHIVE_NAME="ae_${TARGET}.tar.gz"
if [[ "$VERSION" == "latest" ]]; then
  DOWNLOAD_URL="${BASE_URL}/latest/download/${ARCHIVE_NAME}"
else
  DOWNLOAD_URL="${BASE_URL}/download/${VERSION}/${ARCHIVE_NAME}"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "target=$TARGET"
  echo "archive=$ARCHIVE_NAME"
  echo "url=$DOWNLOAD_URL"
  echo "bin_dir=$BIN_DIR"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading ${ARCHIVE_NAME}..."
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/$ARCHIVE_NAME"

tar -xzf "$TMP_DIR/$ARCHIVE_NAME" -C "$TMP_DIR"

if [[ ! -f "$TMP_DIR/${BINARY_NAME}" ]]; then
  echo "Archive did not contain ${BINARY_NAME}" >&2
  exit 1
fi

mkdir -p "$BIN_DIR"
install -m 0755 "$TMP_DIR/${BINARY_NAME}" "$BIN_DIR/${BINARY_NAME}"

echo "Installed ${BINARY_NAME} to ${BIN_DIR}/${BINARY_NAME}"

case ":${PATH}:" in
  *":${BIN_DIR}:"*)
    echo "${BIN_DIR} is already in PATH"
    ;;
  *)
    echo "Add to PATH:"
    echo "  export PATH=\"${BIN_DIR}:\$PATH\""
    ;;
esac

echo "Verify install:"
echo "  ${BINARY_NAME} definition"
