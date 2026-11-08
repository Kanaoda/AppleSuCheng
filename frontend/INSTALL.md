# Build the Apple SuCheng front-end

## Prerequisites

- Full Xcode (not only Command Line Tools)
- Network access for first-time dependency bootstrap

## Steps (from repo root)

```bash
bash packaging/scripts/bootstrap_frontend.sh
bash packaging/scripts/build_frontend.sh
```

`bootstrap_frontend.sh` fetches the GPL upstream sources and dependencies,
then applies Apple SuCheng branding. Override the upstream git URL with
`ASC_UPSTREAM_URL` if needed.

## Make targets

```bash
cd frontend
make release DERIVED_DATA_PATH=build.noindex
```

Output app: `build.noindex/Build/Products/Release/AppleSuCheng.app`
(also copied to `../build.noindex/frontend/AppleSuCheng.app` by the packaging script).
