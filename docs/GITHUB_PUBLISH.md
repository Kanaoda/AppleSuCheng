# 上 GitHub 建議設定

## Repository

- **Name**：`AppleSuCheng` 或 `apple-sucheng`
- **Description**：`macOS Traditional Chinese Sucheng (速成) IME — Windows Sucheng habits for Mac. 蘋果速成 by Kanaoda`
- **Topics**：`macos` `input-method` `ime` `sucheng` `速成` `traditional-chinese` `chinese-input-method` `windows-to-mac` `apple-sucheng` `kanaoda`
- **Website**：可開 Pages 指向 `website/`

## 贊助

`.github/FUNDING.yml` 已設 GitHub Sponsors（`Kanaoda`）與 Buy Me a Coffee。

## Release（一般用戶）

```bash
ASC_PHASE_B=1 bash packaging/scripts/build_preview_app.sh
bash packaging/scripts/make_release.sh
# 上傳 dist.noindex/release/AppleSuCheng-*-macOS.zip
gh release create v0.2.0 dist.noindex/release/AppleSuCheng-*-macOS.zip --title "蘋果速成 v0.2.0" --notes-file docs/RELEASE_NOTES.md
```
