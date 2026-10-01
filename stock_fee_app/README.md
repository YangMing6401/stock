# 📈 台股手續費與獲利損益計算器 (Flutter App)

這是一個專為台灣股市設計的現代化、高質感的股票手續費與交易損益計算器 Flutter App。支援台股現股、當沖、ETF 交易稅率、券商折讓優惠、自訂最低手續費 (低消)、零股/整股試算，以及專業交易者必備的「損益兩平價」與「台股跳動檔位階梯獲利表」。

---

## ✨ 核心特色與功能

1. **完整台股交易成本試算**
   - **法定手續費**：買進與賣出均為 `0.1425%`。
   - **券商手續費折讓**：支援 6折、5折、3.8折、2.8折、2折、1折或自訂任意折數。
   - **低消門檻**：支援預設 20 元低消，或零股優惠 1 元低消與無低消設定。
   - **交易稅率切換**：
     - 一般現股賣出：`0.3%`
     - 現股當沖賣出：`0.15%`
     - ETF (指數型股票基金)：`0.1%`

2. **精確損益兩平價與台股升降單位 (Tick Size) 試算**
   - 不只計算理論兩平價，更自動符合台股法定升降單位（未滿10元跳0.01、10~50元跳0.05、50~100元跳0.1、100~500元跳0.5、500~1000元跳1.0、1000元以上跳5.0）。
   - 推薦「保證獲利之最小跳動檔位賣出價」。
   - **當沖/短線跳動檔位階梯表**：直接列出 +1 檔、+2 檔、+3 檔到 +10 檔的出場價格與扣除所有稅費後的「實賺金額」。

3. **零股 / 整股快速切換**
   - 整股模式：以「張」為單位 (1,000股)，提供 1張、2張、5張、10張快捷鈕。
   - 零股模式：以「股」為單位，提供 50股、100股、200股、500股快捷鈕。

4. **歷史試算紀錄與持久化儲存**
   - 支援將感興趣的標的試算儲存至本地資料庫 (SharedPreferences)。
   - 隨時開啟歷史抽屜查看過去試算，一鍵回填到計算機中。

5. **現代金融深色介面 (Fintech Dark Aesthetic)**
   - 遵循台灣股市「紅漲賺、綠跌賠」配色習慣。
   - 提供詳細的「交易費用明細」彈窗，清楚查驗每一筆手續費與稅金流向。

---

## 🚀 如何安裝 Flutter 與執行本專案

若您的電腦尚未安裝 Flutter SDK，請依照以下步驟設定：

### 步驟 1：下載 Flutter SDK
1. 前往 Flutter 官網下載 Windows 安裝包：
   👉 [https://docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows)
2. 解壓縮至您偏好的目錄，例如 `C:\src\flutter` (避免放在需要管理員權限的目錄如 `C:\Program Files`)。

### 步驟 2：將 Flutter 加入環境變數 (PATH)
1. 在 Windows 搜尋列輸入「編輯系統環境變數」並開啟。
2. 點擊「環境變數」按鈕。
3. 在「使用者變數」或「系統變數」找到 `Path`，點擊「編輯」。
4. 點擊「新增」，填入 `C:\src\flutter\bin`（或您解壓縮的實際路徑）。
5. 點擊確定儲存後，重新開啟終端機 (PowerShell 或 CMD)。

### 步驟 3：安裝與檢驗
在終端機執行：
```bash
flutter doctor
```
檢查開發環境（若要編譯為 Windows 桌面版需安裝 Visual Studio C++ 工具；若要以 Chrome 網頁版測試只需 Chrome 即可；若要打包 Android 需安裝 Android Studio）。

### 步驟 4：執行本 App
進入本專案資料夾：
```bash
cd d:\stock\stock_fee_app

# 下載相依套件
flutter pub get

# 方式 A：直接在 Google Chrome 瀏覽器預覽執行 (最快速零配置)
flutter run -d chrome

# 方式 B：在 Windows 原生桌面執行
flutter run -d windows

# 方式 C：在 Android 手機或模擬器執行
flutter run
```

---

## 🗂️ 專案目錄結構

```
stock_fee_app/
├── lib/
│   ├── main.dart                      # 應用程式入口
│   ├── models/
│   │   ├── broker_setting.dart        # 券商設定 (折讓、低消、四捨五入)
│   │   ├── fee_calculation.dart       # 試算結果資料結構
│   │   └── history_record.dart        # 歷史紀錄資料模型
│   ├── services/
│   │   ├── fee_calculator.dart        # 手續費、證交稅、損益兩平、台股跳動檔位核心邏輯
│   │   └── storage_service.dart       # 本地資料讀寫 (SharedPreferences)
│   ├── theme/
│   │   └── app_theme.dart             # Fintech 深色質感主題與台股紅綠色彩
│   ├── widgets/
│   │   ├── cost_breakdown_dialog.dart # 完整交易費用明細彈窗
│   │   ├── custom_number_field.dart   # 自訂跳動加減輸入框
│   │   ├── history_bottom_sheet.dart  # 歷史紀錄底部彈窗
│   │   ├── profit_summary_card.dart   # 預估淨損益與報酬率核心卡片
│   │   └── quick_discount_chips.dart  # 常用折讓快速切換標籤 (2.8折/5折/6折...)
│   └── screens/
│       ├── calculator_screen.dart     # 主計算機頁面
│       ├── breakeven_screen.dart      # 損益兩平與當沖檔位階梯表頁面
│       └── settings_screen.dart       # 券商參數自訂與常用券商範本
├── web/
│   ├── index.html
│   └── manifest.json
├── pubspec.yaml                       # 套件設定檔
└── README.md
```

---

## 📐 台股交易計算公式參考

- **買進手續費** = `MAX(買進成交金額 × 0.1425% × 折讓率, 券商低消)`
- **買進總成本** = `買進成交金額 + 買進手續費`
- **賣出手續費** = `MAX(賣出成交金額 × 0.1425% × 折讓率, 券商低消)`
- **證券交易稅** = `賣出成交金額 × 稅率 (現股 0.3% / 當沖 0.15% / ETF 0.1%)`
- **賣出實收金額** = `賣出成交金額 - 賣出手續費 - 證券交易稅`
- **淨損益** = `賣出實收金額 - 買進總成本`
- **投資報酬率 (ROI)** = `(淨損益 ÷ 買進總成本) × 100%`
- **損益兩平價** = 讓淨損益大於等於 0 的最低合規台股賣出檔位價
