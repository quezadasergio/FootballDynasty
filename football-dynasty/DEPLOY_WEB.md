# Despliegue web (Netlify)

Sí: el juego se puede jugar en el navegador exportándolo a HTML5/WebAssembly.

## 1. Instalar plantillas (una vez)

```bash
cd football-dynasty
chmod +x scripts/*.sh
./scripts/install_web_templates.sh
```

O en Godot: **Editor → Manage Export Templates → Download and Install**.

## 2. Exportar

```bash
./scripts/export_web.sh
```

También desde el editor: **Proyecto → Exportar → Web** (preset ya creado; salida `build/web/index.html`).

El preset usa **sin threads** para facilitar el hosting en Netlify.

## 3. Probar en local

```bash
cd build/web
python3 -m http.server 8080
```

Abre http://localhost:8080 — **no** abras el `index.html` como archivo (`file://`); hace falta un servidor HTTP.

## 4. Publicar en Netlify

El log `Starting to deploy site from '/'` significa que Netlify publicó la **raíz del repo** (README, código fuente) y **no** el juego. Hace falta:

1. Tener `football-dynasty/build/web/index.html` **en Git** (tras `./scripts/export_web.sh`).
2. Usar el `netlify.toml` de la **raíz** del monorepo (`publish = "football-dynasty/build/web"`), o en el panel de Netlify:
   - **Base directory:** `football-dynasty`
   - **Publish directory:** `build/web`

### Opción A — Arrastrar carpeta

1. Genera `build/web` con el script.
2. En [Netlify](https://app.netlify.com): **Add new site → Deploy manually**.
3. Arrastra la carpeta `football-dynasty/build/web`.

### Opción B — Conectar el repo (recomendado)

1. Sube al repo el contenido de `build/web` **después de exportar**, **o** usa el workflow de GitHub Actions.
2. En Netlify: **Import from Git** → este repositorio.
3. Ajustes (ya vienen en `netlify.toml`):
   - **Publish directory:** `build/web` (si la base del sitio es la carpeta `football-dynasty`, usa esa ruta relativa a la raíz que Netlify vea).
   - Build command: el de `netlify.toml` (no compila Godot; solo sirve estáticos).

Si Netlify apunta a la **raíz del monorepo** (`FootballDynasty/`), cambia en el panel:

- Base directory: `football-dynasty`
- Publish directory: `build/web`

El archivo `netlify.toml` ya define headers COOP/COEP.

### Opción C — GitHub Actions

Hay un workflow en `.github/workflows/export-web.yml` que exporta con Godot 4.7.1.

Para deploy automático a Netlify, añade secrets del repo:

- `NETLIFY_AUTH_TOKEN`
- `NETLIFY_SITE_ID`

## Archivos añadidos

| Archivo | Uso |
|---------|-----|
| `export_presets.cfg` | Preset **Web** |
| `netlify.toml` | Publish dir + headers |
| `scripts/export_web.sh` | Exportación CLI |
| `scripts/install_web_templates.sh` | Descarga plantillas |
| `.github/workflows/export-web.yml` | CI export (+ Netlify opcional) |

## Notas

- La primera carga puede tardar (archivos `.wasm` + `.pck`).
- Guardados quedan en el navegador (IndexedDB / `user://`).
- Si cambias código, vuelve a ejecutar `./scripts/export_web.sh` y redespliega (o deja que Actions lo haga).
