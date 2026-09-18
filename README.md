# LinguaDock

<p align="center">
  <img src="Design/icon-master.png" width="180" alt="LinguaDock app icon">
</p>

LinguaDock 是一个原生 macOS 翻译工具：用全局快捷键读取当前选中文本，自动执行中英互译，并把请求发送到你自己的 Ollama 或 OpenAI-compatible API。

![macOS](https://img.shields.io/badge/macOS-14%2B-111827?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-0F766E)

## MVP 功能

- `⇧⌘T` 在任意 App 中读取选中文本并打开翻译窗口
- 自动方向：中文 → English；其他语言 → 简体中文
- 原生 Ollama `/api/chat` 协议
- OpenAI-compatible `/chat/completions` 协议
- 可配置 API URL、API Key 与模型；Key 存在 macOS Keychain
- `linguadock://translate?text=...` URL Scheme
- 随仓库提供可安装的 PopClip 扩展
- 读取失败时回退到模拟 `⌘C`，并恢复原剪贴板内容

## 本地开发

要求：macOS 14+、Xcode 27（兼容 Swift 6）和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
brew install xcodegen
git clone https://github.com/dofy/LinguaDock.git
cd LinguaDock
xcodegen generate
open LinguaDock.xcodeproj
```

命令行验证：

```bash
xcodegen generate
xcodebuild test \
  -project LinguaDock.xcodeproj \
  -scheme LinguaDock \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## Ollama 快速开始

```bash
ollama pull qwen3.5:9b
ollama serve
```

LinguaDock 默认连接 `http://localhost:11434`，默认模型为 `qwen3.5:9b`，本地 Ollama 通常不需要 API Key。

首次通过快捷键读取其他 App 的选中文本时，请按提示在“系统设置 → 隐私与安全性 → 辅助功能”中允许 LinguaDock。

## OpenAI-compatible 服务

在设置中切换到 **OpenAI Compatible**，填写 Base URL、API Key 和模型名即可。Base URL 应指向版本根路径，例如 `https://api.openai.com/v1`；LinguaDock 会追加 `/chat/completions`。若填写的是完整 `/chat/completions` 地址，也不会重复追加。

## PopClip

```bash
./scripts/build-popclip.sh
open PopClip/LinguaDock.popclipextz
```

扩展会调用：

```text
linguadock://translate?text=<URL-encoded selected text>
```

## 隐私

LinguaDock 不内置遥测。文本只会发送到你在设置中配置的 API 地址。使用本机 Ollama 时，翻译请求无需离开本机。

## License

MIT
