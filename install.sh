#!/bin/sh
# Installs a mannerly release binary.
#   curl -fsSL https://raw.githubusercontent.com/Baimmmss/mannerly/main/install.sh | sh
# Downloads the prebuilt binary from the latest GitHub release. If there is no
# release binary for this machine, builds it from source with cargo instead.
# MANNERLY_INSTALL_DIR chooses where it goes (default: ~/.local/bin).
# MANNERLY_VERSION picks a release tag like v0.1.0 (default: latest).
set -eu

REPO="Baimmmss/mannerly"
DIR="${MANNERLY_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${MANNERLY_VERSION:-latest}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

build_from_source() {
  if ! command -v cargo >/dev/null 2>&1; then
    echo "mannerly: $1, and cargo is not installed to build it from source." >&2
    echo "Install Rust from https://rustup.rs, then run this again." >&2
    exit 1
  fi
  echo "$1; building from source with cargo (takes a minute)…"
  cargo install mannerly --locked --root "$tmp/root"
  mv "$tmp/root/bin/mannerly" "$tmp/mannerly"
}

target=""
case "$(uname -s)" in
  Darwin) os="apple-darwin" ;;
  Linux) os="unknown-linux-musl" ;;
  *) os="" ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) arch="x86_64" ;;
  arm64 | aarch64) arch="aarch64" ;;
  *) arch="" ;;
esac
[ -n "$os" ] && [ -n "$arch" ] && target="$arch-$os"

if [ -z "$target" ]; then
  build_from_source "no prebuilt binary for $(uname -s) $(uname -m)"
else
  if [ "$VERSION" = "latest" ]; then
    base="https://github.com/$REPO/releases/latest/download"
  else
    base="https://github.com/$REPO/releases/download/$VERSION"
  fi
  echo "Downloading mannerly ($VERSION) for $target…"
  if curl -fsSL "$base/mannerly-$target.tar.gz" -o "$tmp/mannerly.tar.gz" 2>/dev/null; then
    if curl -fsSL "$base/mannerly-$target.sha256" -o "$tmp/sum" 2>/dev/null; then
      expected="$(cut -d' ' -f1 < "$tmp/sum")"
      if command -v shasum >/dev/null 2>&1; then actual="$(shasum -a 256 "$tmp/mannerly.tar.gz" | cut -d' ' -f1)"
      else actual="$(sha256sum "$tmp/mannerly.tar.gz" | cut -d' ' -f1)"; fi
      [ "$expected" = "$actual" ] || { echo "mannerly: checksum mismatch, aborting" >&2; exit 1; }
    fi
    tar -xzf "$tmp/mannerly.tar.gz" -C "$tmp"
  else
    build_from_source "no release binary for $target yet"
  fi
fi

mkdir -p "$DIR"
mv "$tmp/mannerly" "$DIR/mannerly"
chmod +x "$DIR/mannerly"

echo "Installed mannerly to $DIR/mannerly"
case ":$PATH:" in
  *":$DIR:"*) echo "Try: mannerly git" ;;
  *) echo "Add $DIR to your PATH, then try: mannerly git" ;;
esac
