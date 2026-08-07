#!/usr/bin/env bash
# Exporta Football Dynasty a HTML5/WebAssembly en build/web/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
  if [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
    GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
  elif command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  else
    echo "No se encontró Godot. Define GODOT_BIN=/ruta/a/Godot"
    exit 1
  fi
fi

echo "Usando: $GODOT_BIN"
FULL_VER="$("$GODOT_BIN" --version || true)"
echo "Versión: $FULL_VER"

SHORT_VER="$(echo "$FULL_VER" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
TEMPLATE_DIR="${HOME}/Library/Application Support/Godot/export_templates/${SHORT_VER}.stable"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Plantillas no encontradas en: $TEMPLATE_DIR"
  echo "Ejecuta: ./scripts/install_web_templates.sh"
  exit 1
fi

mkdir -p build/web

echo "Importando recursos ..."
"$GODOT_BIN" --headless --path "$ROOT" --import || true

echo "Exportando Web → build/web/index.html ..."
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Web" "$ROOT/build/web/index.html"

# Headers Netlify (por si publicas solo la carpeta build/web)
cat > build/web/_headers <<'EOF'
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  X-Content-Type-Options: nosniff

/*.wasm
  Content-Type: application/wasm

/*.pck
  Content-Type: application/octet-stream
EOF

echo ""
echo "Listo. Contenido de build/web:"
ls -lh build/web
echo ""
echo "Prueba local:"
echo "  cd build/web && python3 -m http.server 8080"
echo "  Abre http://localhost:8080"
