# Apple SuCheng front-end architecture

Use this note when changing the macOS InputMethodKit front-end under `frontend/`.

## Layout

- `sources/Main.swift` — process entry, CLI maintenance, IMK server
- `sources/AppleSuChengApplicationDelegate.swift` — panel, config, status item, Rime lifecycle
- `sources/AppleSuChengInputController.swift` — key events, sessions, candidates
- `sources/AppleSuChengConfig.swift` / `AppleSuChengTheme.swift` / `AppleSuChengPanel.swift` / `AppleSuChengView.swift`
- `sources/InputSource.swift` — TIS register / enable / select
- `resources/Info.plist` — IMK registration (branded by packaging scripts)
- `data/applesucheng.yaml` — UI config deployed as `applesucheng.yaml`

## Product packaging

Prefer `packaging/scripts/build_preview_app.sh` + `install_preview.sh` so icons,
schemas, Lua, and localized names stay product-branded.
