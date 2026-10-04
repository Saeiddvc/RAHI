#!/usr/bin/env bash
# Download the pinned Vazirmatn fonts used by RAHI.
# Usage: bash tools/download_fonts.sh
set -euo pipefail

VERSION="v33.003"
FONT_DIR="assets/fonts/Vazirmatn"
BASE_RAW="https://raw.githubusercontent.com/rastikerdar/vazirmatn/${VERSION}/fonts/ttf"
RELEASE_ZIP="https://github.com/rastikerdar/vazirmatn/releases/download/${VERSION}/vazirmatn-${VERSION}.zip"

FONTS=(
  "Vazirmatn-Regular.ttf"
  "Vazirmatn-Medium.ttf"
  "Vazirmatn-Bold.ttf"
)

mkdir -p "$FONT_DIR"

validate_font() {
  local path="$1"
  [ -f "$path" ] || return 1
  local size
  size=$(wc -c < "$path")
  [ "$size" -ge 50000 ]
}

download_raw() {
  local name="$1"
  local dest="$FONT_DIR/$name"

  if validate_font "$dest"; then
    echo "  ✓ $name (already present)"
    return 0
  fi

  rm -f "$dest"
  echo "  ↓ $name"
  if ! curl -fsSL "$BASE_RAW/$name" -o "$dest"; then
    rm -f "$dest"
    return 1
  fi

  if ! validate_font "$dest"; then
    echo "  ⚠️ $name is missing or unexpectedly small."
    rm -f "$dest"
    return 1
  fi
}

echo "📥 Preparing Vazirmatn ${VERSION} fonts..."
RAW_OK=1
for font in "${FONTS[@]}"; do
  if ! download_raw "$font"; then
    RAW_OK=0
    break
  fi
done

if [ "$RAW_OK" -eq 0 ]; then
  echo "⚠️ Direct download failed; using the official release ZIP."
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  curl -fsSL "$RELEASE_ZIP" -o "$tmp_dir/vazirmatn.zip"
  unzip -q "$tmp_dir/vazirmatn.zip" -d "$tmp_dir/extracted"

  for font in "${FONTS[@]}"; do
    source_path=$(find "$tmp_dir/extracted" -type f -path "*/fonts/ttf/$font" -print -quit)
    if [ -z "$source_path" ]; then
      echo "❌ Could not find $font inside the official release ZIP."
      exit 1
    fi
    cp "$source_path" "$FONT_DIR/$font"
    if ! validate_font "$FONT_DIR/$font"; then
      echo "❌ Invalid font after ZIP extraction: $font"
      exit 1
    fi
  done
fi

echo "✅ Vazirmatn fonts are ready:"
for font in "${FONTS[@]}"; do
  size=$(wc -c < "$FONT_DIR/$font")
  echo "  ✓ $font ($size bytes)"
done
