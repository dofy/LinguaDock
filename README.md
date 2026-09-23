# LinguaDock

**English** · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md)

<p align="center">
  <img src="Design/icon-master.png" width="156" alt="LinguaDock app icon">
</p>

<p align="center"><strong>Select, summon, understand.</strong></p>

<p align="center">
  LinguaDock is a native macOS translation tool. It carries text you selected in
  another app, a region you dragged out on screen, or an image on the clipboard
  into one clean translation window, and translates it with the local model or
  OpenAI-compatible service of your choice.
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-171614?logo=apple&logoColor=white">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-FF6554?logo=swift&logoColor=white">
  <img alt="MIT License" src="https://img.shields.io/badge/license-MIT-52717A">
</p>

## A shorter route to a translation

Reading mail, a document, a web page or some code, you shouldn't have to copy the
text, switch to a web page, find the input field, and carry the result back.

1. Select text in any app.
2. Press your own global shortcut, click LinguaDock in PopClip, or run Translate
   Text in Raycast.
3. Read and copy the translation in a native window, switching the target
   language whenever you like.

LinguaDock detects the source language itself. The prompt is built around keeping
tone, proper nouns, Markdown, paragraphs and code blocks intact, and adding no
commentary.

## Text you can't select, translated anyway

Images, video subtitles, scans, a screenshot someone sent you — that text can't
be copied. LinguaDock pulls it out with the system's own text recognition and
then translates it. Recognition happens entirely on this machine:

- **Screen capture** (`⌃⇧⌘O` by default, changeable in Settings): drag out any
  region of the screen just like a system screenshot. The result lands in the
  source field and translation starts.
- **Paste an image** (`⌘⇧V`): recognizes the image on the clipboard. If the
  clipboard holds an image and no text, plain `⌘V` goes through recognition too.
- The viewfinder and image buttons at the top right of the source field do the
  same thing.

Screen capture needs a one-time Screen Recording permission; LinguaDock offers a
one-click jump to the right System Settings pane when it's needed.

## The model is yours to pick

LinguaDock isn't tied to one translation vendor:

- Use **Ollama** and keep both the text and the model on this machine.
- Use any **OpenAI-compatible API** with your own base URL, API key and model
  name.
- API keys for different protocols are stored separately in the macOS Keychain.

The app ships no telemetry. Text goes only to the service you chose in Settings;
with a local Ollama, a translation request never has to leave the Mac.

## Built for the way macOS works

- Native SwiftUI windows and a native Settings experience
- Recordable, changeable global shortcuts — one for reading the selection, one
  for screen capture
- On-device OCR through the system Vision framework, covering Chinese, English,
  Japanese, Korean and other common languages, with automatic detection
- A list of the major target languages; your choice is remembered
- Accessibility authorization status refreshes itself
- A `linguadock://translate?text=...` URL scheme
- An installable PopClip extension and a standalone Raycast extension, both in
  this repo
- Falls back to a simulated `⌘C` when reading the selection fails, restoring the
  original clipboard afterwards
- A trilingual interface — English, 简体中文, 繁體中文 — following the system
  language

## Getting started

### A local model

```bash
ollama pull qwen3.5:9b
ollama serve
```

Pick **Ollama** in LinguaDock's settings. The default address is
`http://localhost:11434`, and a local service usually needs no API key.

### An OpenAI-compatible service

Pick **OpenAI Compatible** in Settings and fill in the base URL, API key and
model. The base URL can be a version root (`https://api.openai.com/v1`, say) or a
complete `/chat/completions` address — LinguaDock completes the request path
correctly either way.

The first time it reads selected text from another app, allow LinguaDock under
System Settings → Privacy & Security → Accessibility.

## The PopClip extension

```bash
./scripts/build-popclip.sh
open PopClip/LinguaDock.popclipextz
```

The extension hands the selected text to LinguaDock through the URL scheme:

```text
linguadock://translate?text=<URL-encoded selected text>
```

## The Raycast extension

[`Raycast/`](Raycast/) in this repo is a standalone Raycast translation client
that neither installs nor runs the LinguaDock macOS app. It calls the
OpenAI-compatible API you configured directly, and supports reading the
selection, automatic Chinese/English target choice, picking a target language by
hand, restoring list formatting, and copying or pasting the result.

```bash
cd Raycast
pnpm install
pnpm dev
```

Fill in the API base URL, API key and model in Raycast on first launch. Raycast
stores the API key as a password preference; it never lands in the repo.

## Localization

The UI ships in English, Simplified Chinese and Traditional Chinese, following the
system language. There is no in-app language picker — set it per app under System
Settings → General → Language & Region.

- Source language is `en`. Every `defaultValue` in the Swift code is English.
- Copy lives in `LinguaDock/Resources/Localizable.xcstrings`, and the permission
  string in `LinguaDock/Resources/InfoPlist.xcstrings`.
- `./scripts/check-localization.sh` (also a CI step) fails on a missing key, a
  missing translation, an orphaned catalog entry, or Chinese hardcoded in Swift.
  Legitimate exceptions carry a trailing `// i18n-exempt` comment.
- **`TargetLanguage.promptName` must stay English** — it goes into the system
  prompt sent to the model. Only `displayName` is localized, and
  `LinguaDockTests/TargetLanguageTests.swift` guards the difference.
- The PopClip extension carries its own trilingual strings in
  `PopClip/LinguaDock.popclipext/Config.yaml` and `Main.js`. Raycast extensions
  have no localization mechanism and stay English by convention.

## Local development

Requirements: macOS 14+, Xcode 27 (Swift 6 compatible) and
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/dofy/LinguaDock.git
cd LinguaDock
xcodegen generate
open LinguaDock.xcodeproj
```

Running the tests:

```bash
xcodegen generate
xcodebuild test \
  -project LinguaDock.xcodeproj \
  -scheme LinguaDock \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
./scripts/check-localization.sh
```

Installing a local debug build:

```bash
./scripts/install-local.sh
```

The first run of that script creates a LinguaDock-specific local code-signing
identity in your login keychain, so the Accessibility grant survives later local
updates. That identity is for development on this machine only.

## Project

- GitHub: [github.com/dofy/LinguaDock](https://github.com/dofy/LinguaDock)
- Issues: [GitHub Issues](https://github.com/dofy/LinguaDock/issues)
- License: [MIT](LICENSE)
