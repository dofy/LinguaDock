# LinguaDock

<p align="center">
  <img src="Design/icon-master.png" width="156" alt="LinguaDock app icon">
</p>

<p align="center"><strong>选中，唤起，读懂。</strong></p>

<p align="center">
  LinguaDock 是一款原生 macOS 翻译工具。它把其他 App 中选中的文字、屏幕上框选的区域，
  或剪贴板里的图片带进一个干净的翻译窗口，并使用你选择的本地模型或 OpenAI-compatible 服务完成翻译。
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-171614?logo=apple&logoColor=white">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-FF6554?logo=swift&logoColor=white">
  <img alt="MIT License" src="https://img.shields.io/badge/license-MIT-52717A">
</p>

## 一条更短的翻译路径

阅读邮件、文档、网页或代码时，不必复制文字、切换网页、寻找输入框，再把结果带回来。

1. 在任意 App 中选中文字。
2. 按下自定义全局快捷键、点击 PopClip 中的 LinguaDock，或运行 Raycast 的 Translate Text。
3. 在原生窗口中查看、复制译文，并随时切换目标语言。

LinguaDock 会自动识别原文语言。翻译提示专注于保留语气、专有名词、Markdown、段落和代码块，不添加额外解释。

## 选不中的文字，也能翻

图片、视频字幕、扫描件、别人发来的截图——这些地方的文字复制不出来。LinguaDock 用系统自带的
文字识别把它们取出来再翻译，识别全程在本机完成：

- **截屏识别**（默认 `⌃⇧⌘O`，可在设置中改）：像系统截图一样框选屏幕上任意区域，识别结果直接进原文框并开始翻译。
- **粘贴图片**（`⌘⇧V`）：剪贴板里是图片时识别它。如果剪贴板里只有图片、没有文字，直接按 `⌘V` 也会走识图。
- 也可以点原文框右上角的取景框 / 图片按钮触发。

截屏识别需要一次性的「屏幕录制」权限；LinguaDock 会在需要时给出一键跳转系统设置的提示。

## 模型由你决定

LinguaDock 不绑定单一翻译供应商：

- 使用 **Ollama**，让文本和模型都留在本机。
- 使用任意 **OpenAI-compatible API**，配置自己的 Base URL、API Key 和模型名称。
- 不同协议的 API Key 分开保存在 macOS Keychain 中。

应用不内置遥测。文本只会发送到你在设置中选择的服务；使用本机 Ollama 时，翻译请求无需离开 Mac。

## 为 macOS 交互而生

- 原生 SwiftUI 窗口与系统设置体验
- 可录制、可随时修改的全局快捷键（读取选中文本 / 截屏识别各一组）
- 基于系统 Vision 框架的本机 OCR，支持中英日韩等常见语言，自动检测语种
- 主流目标语言列表，选择会被记住
- 辅助功能授权状态自动刷新
- `linguadock://translate?text=...` URL Scheme
- 随仓库提供可安装的 PopClip 扩展和独立运行的 Raycast 扩展
- 读取选区失败时回退到模拟 `⌘C`，并恢复原剪贴板内容

## 开始使用

### 本机模型

```bash
ollama pull qwen3.5:9b
ollama serve
```

在 LinguaDock 设置中选择 **Ollama**。默认地址为 `http://localhost:11434`，本地服务通常不需要 API Key。

### OpenAI-compatible 服务

在设置中选择 **OpenAI Compatible**，填写 Base URL、API Key 与模型。Base URL 可以是版本根路径（例如 `https://api.openai.com/v1`）或完整的 `/chat/completions` 地址，LinguaDock 会正确补全请求路径。

首次从其他 App 读取选中文本时，请在“系统设置 → 隐私与安全性 → 辅助功能”中允许 LinguaDock。

## PopClip 扩展

```bash
./scripts/build-popclip.sh
open PopClip/LinguaDock.popclipextz
```

扩展通过 URL Scheme 把选中的文本交给 LinguaDock：

```text
linguadock://translate?text=<URL-encoded selected text>
```

## Raycast 扩展

仓库中的 [`Raycast/`](Raycast/) 是一个独立的 Raycast 翻译客户端，不要求安装或运行 LinguaDock macOS App。它直接调用用户配置的 OpenAI-compatible API，支持读取选中文本、自动中英目标判断、手动目标语言选择、列表格式恢复，以及复制或粘贴译文。

```bash
cd Raycast
pnpm install
pnpm dev
```

首次启动时在 Raycast 中填写 API Base URL、API Key 和模型。API Key 由 Raycast 作为密码偏好保存，不会写入仓库。

## 本地开发

要求：macOS 14+、Xcode 27（兼容 Swift 6）和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
brew install xcodegen
git clone https://github.com/dofy/LinguaDock.git
cd LinguaDock
xcodegen generate
open LinguaDock.xcodeproj
```

运行测试：

```bash
xcodegen generate
xcodebuild test \
  -project LinguaDock.xcodeproj \
  -scheme LinguaDock \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

安装本机调试版：

```bash
./scripts/install-local.sh
```

首次运行安装脚本时会在登录钥匙串中创建 LinguaDock 专用的本地代码签名身份，让辅助功能授权在后续本地更新中保持有效。该身份只用于本机开发。

## 项目

- GitHub：[github.com/dofy/LinguaDock](https://github.com/dofy/LinguaDock)
- 问题反馈：[GitHub Issues](https://github.com/dofy/LinguaDock/issues)
- License：[MIT](LICENSE)
