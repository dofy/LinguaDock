# LinguaDock

[English](README.md) · [简体中文](README.zh-Hans.md) · **繁體中文**

[**linguadock.phpz.org** ↗](https://linguadock.phpz.org)

<p align="center">
  <img src="Design/icon-master.png" width="156" alt="LinguaDock app icon">
</p>

<p align="center"><strong>選取，喚起，讀懂。</strong></p>

<p align="center">
  LinguaDock 是一款原生 macOS 翻譯工具。它把你在其他 App 中選取的文字、在螢幕上框選的區域，
  或剪貼板裡的圖片帶進一個乾淨的翻譯視窗，並用你選擇的本機模型或 OpenAI-compatible 服務完成翻譯。
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-171614?logo=apple&logoColor=white">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-FF6554?logo=swift&logoColor=white">
  <img alt="MIT License" src="https://img.shields.io/badge/license-MIT-52717A">
</p>

## 一條更短的翻譯路徑

讀郵件、文件、網頁或程式碼時，不必複製文字、切去網頁、找輸入框，再把結果帶回來。

1. 在任何 App 中選取文字。
2. 按下自訂的全域快速鍵、點一下 PopClip 裡的 LinguaDock，或執行 Raycast 的 Translate Text。
3. 在原生視窗中查看、複製譯文，並隨時切換目標語言。

LinguaDock 會自動偵測原文語言。翻譯 prompt 專注在保留語氣、專有名詞、Markdown、段落和
程式碼區塊，不添加額外解釋。

## 選不到的文字，也能翻

圖片、影片字幕、掃描件、別人傳來的截圖 —— 這些地方的文字複製不出來。LinguaDock 用系統
內建的文字辨識把它們取出來再翻譯，辨識全程在本機完成：

- **擷取螢幕**（預設 `⌃⇧⌘O`，可在設定中修改）：像系統截圖一樣框選螢幕上任一區域，辨識
  結果直接進原文欄並開始翻譯。
- **貼上圖片**（`⌘⇧V`）：剪貼板裡是圖片時辨識它。如果剪貼板裡只有圖片、沒有文字，直接按
  `⌘V` 也會走辨識。
- 也可以點原文欄右上角的取景框 / 圖片按鈕。

擷取螢幕需要一次性的「螢幕錄製」權限；LinguaDock 會在需要時給出一鍵跳到系統設定的提示。

## 模型由你決定

LinguaDock 不綁定單一翻譯供應商：

- 用 **Ollama**，讓文字和模型都留在這台機器上。
- 用任何 **OpenAI-compatible API**，設定自己的 Base URL、API Key 和模型名稱。
- 不同協定的 API Key 分開存在 macOS 鑰匙串裡。

App 不內建遙測。文字只會傳送到你在設定中選的服務；用本機的 Ollama 時，翻譯請求不需要
離開 Mac。

## 為 macOS 的互動方式而做

- 原生 SwiftUI 視窗與原生的設定體驗
- 可錄製、可隨時修改的全域快速鍵（讀取選取文字 / 擷取螢幕各一組）
- 基於系統 Vision 框架的本機 OCR，涵蓋中英日韓等常見語言，並自動偵測語種
- 主要目標語言清單，你的選擇會被記住
- 輔助使用授權狀態會自動重新整理
- `linguadock://translate?text=...` URL Scheme
- 隨 repo 提供可安裝的 PopClip 擴充功能，以及可獨立執行的 Raycast 擴充功能
- 讀取選取範圍失敗時回退到模擬 `⌘C`，並還原原本的剪貼板內容
- 三語介面 —— English、简体中文、繁體中文 —— 跟隨系統語言

## 開始使用

### 本機模型

```bash
ollama pull qwen3.5:9b
ollama serve
```

在 LinguaDock 設定中選 **Ollama**。預設位址是 `http://localhost:11434`，本機服務通常不需要
API Key。

### OpenAI-compatible 服務

在設定中選 **OpenAI Compatible**，填寫 Base URL、API Key 與模型。Base URL 可以是版本根路徑
（例如 `https://api.openai.com/v1`）或完整的 `/chat/completions` 位址，LinguaDock 兩種都能
正確補全請求路徑。

第一次從其他 App 讀取選取的文字時，請在「系統設定 → 隱私權與安全性 → 輔助使用」中允許
LinguaDock。

## PopClip 擴充功能

```bash
./scripts/build-popclip.sh
open PopClip/LinguaDock.popclipextz
```

擴充功能透過 URL Scheme 把選取的文字交給 LinguaDock：

```text
linguadock://translate?text=<URL-encoded selected text>
```

## Raycast 擴充功能

repo 裡的 [`Raycast/`](Raycast/) 是一個獨立的 Raycast 翻譯用戶端，不需要安裝或執行
LinguaDock macOS App。它直接呼叫你設定的 OpenAI-compatible API，支援讀取選取的文字、
自動判斷中英目標、手動選目標語言、還原列表排版，以及複製或貼上譯文。

```bash
cd Raycast
pnpm install
pnpm dev
```

第一次啟動時在 Raycast 中填寫 API Base URL、API Key 和模型。API Key 由 Raycast 當成密碼
偏好設定儲存，不會寫進 repo。

## 本機化

介面提供 English、简体中文、繁體中文，跟隨系統語言。App 內沒有語言選擇器 —— 請在
「系統設定 → 一般 → 語言與地區」裡針對單一 App 設定。

- 源語言是 `en`，Swift 程式碼裡的每個 `defaultValue` 都是英文。
- 文案放在 `LinguaDock/Resources/Localizable.xcstrings`，權限說明放在
  `LinguaDock/Resources/InfoPlist.xcstrings`。
- `./scripts/check-localization.sh`（也是 CI 的一步）會在缺 key、缺譯文、有孤兒條目，或
  Swift 裡硬編碼中文時失敗。合法例外在行尾加 `// i18n-exempt`。
- **`TargetLanguage.promptName` 必須保持英文** —— 它會進到發給模型的 system prompt。只有
  `displayName` 本機化，`LinguaDockTests/TargetLanguageTests.swift` 守著這個差別。
- PopClip 擴充功能自己帶三語文案，在 `PopClip/LinguaDock.popclipext/Config.yaml` 與
  `Main.js`。Raycast 擴充功能沒有本機化機制，按慣例保持英文。

## 本機開發

需求：macOS 14+、Xcode 27（相容 Swift 6）以及
[XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
brew install xcodegen
git clone https://github.com/dofy/LinguaDock.git
cd LinguaDock
xcodegen generate
open LinguaDock.xcodeproj
```

執行測試：

```bash
xcodegen generate
xcodebuild test \
  -project LinguaDock.xcodeproj \
  -scheme LinguaDock \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
./scripts/check-localization.sh
```

安裝本機除錯版：

```bash
./scripts/install-local.sh
```

第一次執行安裝腳本時，會在登入鑰匙串中建立 LinguaDock 專用的本機程式碼簽署身分，讓輔助
使用授權在之後的本機更新中保持有效。這個身分只用於這台機器上的開發。

## 專案

- GitHub：[github.com/dofy/LinguaDock](https://github.com/dofy/LinguaDock)
- 問題回報：[GitHub Issues](https://github.com/dofy/LinguaDock/issues)
- 網站：[`website/`](website/README.md) → [linguadock.phpz.org](https://linguadock.phpz.org)
- License：[MIT](LICENSE)
