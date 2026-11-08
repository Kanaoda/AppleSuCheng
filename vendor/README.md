# vendor／引擎快取（階段 A）

預覽包的 macOS 前端二進位來自開源引擎（GPL），**不是**本倉庫的產品原始碼。

## 用法

```bash
# 從本機已安裝的蘋果速成／蘋果速成快取一份，之後可離線 rebuild
bash packaging/scripts/vendor_engine.sh

bash packaging/scripts/build_preview_app.sh
```

或：

```bash
export ASC_ENGINE_APP="/path/to/SomeEngine.app"
bash packaging/scripts/build_preview_app.sh
```

`engine/` 目錄已列入 `.gitignore`，請勿把 GPL 二進位當成自有原始碼提交。  
階段 B 會改為可從原始碼編譯的自有／合法 fork 前端。
