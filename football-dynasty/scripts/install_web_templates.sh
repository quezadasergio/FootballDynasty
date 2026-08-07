#!/usr/bin/env bash
# Descarga e instala plantillas de exportación de Godot (incluye Web).
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT_BIN" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  else
    echo "No se encontró Godot."
    exit 1
  fi
fi

FULL_VER="$("$GODOT_BIN" --version)"
# 4.7.1.stable.official.a13da4feb → 4.7.1
SHORT_VER="$(echo "$FULL_VER" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
TEMPLATE_FOLDER="${SHORT_VER}.stable"
DEST="${HOME}/Library/Application Support/Godot/export_templates/${TEMPLATE_FOLDER}"

if [[ -d "$DEST" ]] && [[ -f "$DEST/web_release.zip" || -f "$DEST/web_dlink_release.zip" || -f "$DEST/web_nothreads_release.zip" ]]; then
  echo "Plantillas ya instaladas en: $DEST"
  ls "$DEST" | rg -i 'web' || ls "$DEST" | head
  exit 0
fi

URL="https://github.com/godotengine/godot-builds/releases/download/${SHORT_VER}-stable/Godot_v${SHORT_VER}-stable_export_templates.tpz"
# Fallback oficial
URL2="https://github.com/godotengine/godot/releases/download/${SHORT_VER}-stable/Godot_v${SHORT_VER}-stable_export_templates.tpz"

TMP="$(mktemp -d)"
TPZ="${TMP}/templates.tpz"
echo "Descargando plantillas ${SHORT_VER}-stable..."
if ! curl -fL --progress-bar -o "$TPZ" "$URL"; then
  echo "Reintentando con URL alternativa..."
  curl -fL --progress-bar -o "$TPZ" "$URL2"
fi

echo "Extrayendo en $DEST ..."
mkdir -p "$DEST"
# El .tpz es un zip; dentro suele haber carpeta templates/
unzip -q -o "$TPZ" -d "$TMP/extracted"
if [[ -d "$TMP/extracted/templates" ]]; then
  cp -R "$TMP/extracted/templates/"* "$DEST/"
else
  cp -R "$TMP/extracted/"* "$DEST/"
fi

rm -rf "$TMP"
echo "Listo: $DEST"
ls "$DEST" | head -30
