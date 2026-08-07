# Football Dynasty

A football management simulation built with Godot. Build your squad, manage finances, climb the leagues, and turn a small club into a Mexican football dynasty.

## Tech stack

| Layer | Technology |
|--------|------------|
| Engine | [Godot](https://godotengine.org/) **4.7** |
| Language | **GDScript** |
| Rendering | **GL Compatibility** (desktop / mobile / web) |
| Physics | **Jolt Physics** (engine default) |
| Game data | **JSON** (`data/leagues.json`, `foreign_clubs.json`, `names.json`, …) |
| Web export | **HTML5 / WebAssembly** (Godot Web preset, no threads) |
| Hosting | **[Netlify](https://www.netlify.com/)** (`netlify.toml`) |
| CI (optional) | **GitHub Actions** (`.github/workflows/export-web.yml`) |
| Local web preview | **Python 3** (`http.server`) |

Project code lives under [`football-dynasty/`](football-dynasty/).

## How to run

### Desktop (Godot editor)

1. Install [Godot 4.7](https://godotengine.org/download/) (standard build).
2. Open Godot → **Import** → select `football-dynasty/project.godot`.
3. Press **F5** (or the Play button). The main scene is `scenes/main_menu.tscn`.

### Web export (local)

```bash
cd football-dynasty
chmod +x scripts/*.sh
./scripts/install_web_templates.sh   # once
./scripts/export_web.sh
cd build/web
python3 -m http.server 8080
```

Open [http://localhost:8080](http://localhost:8080). Do not open `index.html` via `file://`; a local HTTP server is required.

More detail: [football-dynasty/DEPLOY_WEB.md](football-dynasty/DEPLOY_WEB.md).

## Play online

Try the live build: [https://football-dynasty.netlify.app/](https://football-dynasty.netlify.app/)
