# Apple SuCheng front-end (fork)

This directory is the macOS InputMethodKit front-end used by **蘋果速成 / Apple SuCheng**.

It is a GPL-3.0 fork of the Rime project's official macOS IMK front-end.
See `UPSTREAM.md` and `LICENSE.txt`.

## Build

From the repository root (recommended):

```bash
bash packaging/scripts/bootstrap_frontend.sh
bash packaging/scripts/build_frontend.sh
ASC_PHASE_B=1 bash packaging/scripts/build_preview_app.sh
bash packaging/scripts/install_preview.sh
```

Or inside this directory after bootstrap:

```bash
make release DERIVED_DATA_PATH=build.noindex
```

Product packaging (icons, schemas, Info.plist branding) is applied by
`packaging/scripts/build_preview_app.sh`, not by a bare Xcode build alone.
