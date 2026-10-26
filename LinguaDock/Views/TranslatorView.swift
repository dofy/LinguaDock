import AppKit
import SwiftUI

struct TranslatorView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var speech = SpeechService()
    @FocusState private var sourceFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)

            if appState.needsAccessibilityPermission {
                accessibilityBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }

            if appState.needsScreenRecordingPermission {
                screenRecordingBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }

            GeometryReader { geometry in
                VStack(spacing: 10) {
                    directionBar
                    let layout = geometry.size.width >= 1100
                        ? AnyLayout(HStackLayout(spacing: 12))
                        : AnyLayout(VStackLayout(spacing: 12))
                    layout {
                        editorCard(
                            title: String(localized: "translator.source", defaultValue: "Source"),
                            text: $appState.sourceText,
                            placeholder: sourcePlaceholder,
                            editable: true
                        )
                        resultCard
                    }
                }
            }
            .padding(16)

            footer
        }
        .frame(minWidth: 620, minHeight: 520)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(WindowAccessor())
        .onAppear {
            appState.refreshAccessibilityStatus()
            sourceFocused = appState.sourceText.isEmpty
        }
        .onDisappear { speech.stop() }
        .onChange(of: appState.sourceText) {
            if speech.activeContent == .source { speech.stop() }
        }
        .onChange(of: appState.translatedText) {
            if speech.activeContent == .translation { speech.stop() }
        }
        .onChange(of: appState.isTranslating) {
            if appState.isTranslating { speech.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if let window = notification.object as? NSWindow,
               window.identifier?.rawValue == AppState.mainWindowIdentifier {
                speech.stop()
            }
        }
        .alert(String(localized: "speech.error.title", defaultValue: "Unable to read aloud"),
               isPresented: Binding(get: { speech.errorMessage != nil },
                                    set: { if !$0 { speech.errorMessage = nil } })) {
            Button(String(localized: "common.ok", defaultValue: "OK")) { speech.errorMessage = nil }
        } message: {
            Text(speech.errorMessage ?? "")
        }
        .alert(
            String(localized: "translator.alert.title", defaultValue: "Translation failed"),
            isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { if !$0 { appState.errorMessage = nil } }
            )
        ) {
            Button(String(localized: "common.ok", defaultValue: "OK")) {
                appState.errorMessage = nil
            }
            SettingsLink {
                Text(String(localized: "common.opensettings", defaultValue: "Open Settings"))
            }
        } message: {
            Text(appState.errorMessage
                 ?? String(localized: "error.unknown", defaultValue: "Unknown error"))
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("BrandIcon")
                .resizable()
                .frame(width: 28, height: 28)
            Text(verbatim: "LinguaDock")
                .font(.system(size: 15, weight: .semibold))
                .help(String(localized: "app.tagline", defaultValue: "Read any language with ease"))
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(String(localized: "common.settings", defaultValue: "Settings"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(.orange)
            Text(accessibilityHint)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button(String(localized: "translator.banner.grant", defaultValue: "Grant access")) {
                appState.requestAccessibilityPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var screenRecordingBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.dashed.badge.record")
                .foregroundStyle(.orange)
            Text(String(localized: "translator.banner.screenrecording",
                        defaultValue: "Screen capture needs Screen Recording permission. Allow LinguaDock in System Settings, then try again."))
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button(String(localized: "common.opensettings", defaultValue: "Open Settings")) {
                appState.openScreenRecordingSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    /// 图片入口：框选截屏识别 + 识别剪贴板里的图片。
    private var imageInputButtons: some View {
        HStack(spacing: 8) {
            imageInputActions
        }
        .labelStyle(.titleAndIcon)
        .font(.system(size: 12, weight: .semibold))
        .buttonStyle(.bordered)
        .tint(.accentColor)
        .controlSize(.regular)
        .disabled(appState.isRecognizing)
    }

    @ViewBuilder
    private var imageInputActions: some View {
        Button { appState.captureScreenAndTranslate() } label: {
            Label(String(localized: "translator.capture", defaultValue: "Capture the screen"),
                  systemImage: "text.viewfinder")
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        }
        .help(captureHelp)

        Button { appState.translatePasteboardImage() } label: {
            Label(String(localized: "translator.pasteboard",
                         defaultValue: "Recognize a clipboard image"),
                  systemImage: "photo.on.rectangle.angled")
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        }
        .keyboardShortcut("v", modifiers: [.command, .shift])
        .help(String(localized: "translator.pasteboard.help",
                     defaultValue: "Recognize the image on the clipboard and translate it (⌘⇧V)"))
    }

    private var directionBar: some View {
        HStack(spacing: 10) {
            Text(appState.detectedSourceLanguage?.displayName
                 ?? String(localized: "translator.detect", defaultValue: "Detect language"))
            Image(systemName: "arrow.right")
                .accessibilityHidden(true)
            Picker(String(localized: "translator.target", defaultValue: "Target language"),
                   selection: translationTargetBinding) {
                Text(String(localized: "translator.smart.target",
                            defaultValue: "Smart · \(appState.smartTranslationDirection.target.displayName)"))
                    .tag("auto")
                Divider()
                ForEach(TargetLanguage.allCases) { language in
                    Text(language.displayName).tag(language.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .help(String(localized: "translator.smart.help",
                         defaultValue: "Smart translation uses your preferred language, switching to the alternate when the source already matches. Configure both in Settings, or select a fixed target here."))
            .accessibilityIdentifier("translation-target")
            Spacer(minLength: 12)
            ViewThatFits(in: .horizontal) {
                imageInputButtons.fixedSize()
                Menu {
                    imageInputActions
                } label: {
                    Label(String(localized: "translator.imageinput", defaultValue: "Image translation"),
                          systemImage: "photo.on.rectangle.angled")
                }
                .fixedSize()
                .disabled(appState.isRecognizing)
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
    }

    private var translationTargetBinding: Binding<String> {
        Binding(
            get: { appState.smartTranslationEnabled ? "auto" : appState.targetLanguage.rawValue },
            set: { value in
                if value == "auto" {
                    appState.smartTranslationEnabled = true
                } else if let language = TargetLanguage(rawValue: value) {
                    appState.targetLanguage = language
                    appState.smartTranslationEnabled = false
                }
            }
        )
    }

    private func editorCard(
        title: String,
        text: Binding<String>,
        placeholder: String,
        editable: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text(String(localized: "translator.charcount",
                            defaultValue: "\(text.wrappedValue.count) characters"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                speechButton(content: .source)
            }
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16, weight: .regular))
                        .lineSpacing(4)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: text)
                    .font(.system(size: 16, weight: .regular))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .padding(.vertical, 8)
                    .focused($sourceFocused)
                    .disabled(!editable)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 145, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.separator.opacity(0.45)))
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "translator.result", defaultValue: "Translation"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                speechButton(content: .translation)
                if !appState.translatedText.isEmpty {
                    Button { appState.copyTranslation() } label: {
                        Label(String(localized: "translator.copy", defaultValue: "Copy"),
                              systemImage: "doc.on.doc")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            ScrollView {
                Text(appState.translatedText.isEmpty
                     ? String(localized: "translator.result.placeholder",
                              defaultValue: "The translation will appear here")
                     : appState.translatedText)
                    .font(.system(size: 16, weight: .regular))
                    .lineSpacing(4)
                    .foregroundStyle(appState.translatedText.isEmpty ? .tertiary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 145, maxHeight: .infinity)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor.opacity(0.22)))
    }

    private func speechButton(content: SpeechService.Content) -> some View {
        let isSource = content == .source
        let text = isSource ? appState.sourceText : appState.translatedText
        let isActive = speech.activeContent == content
        let label = isActive
            ? String(localized: "speech.stop", defaultValue: "Stop reading")
            : String(localized: "speech.read", defaultValue: "Read aloud")
        return Button {
            speech.toggle(text,
                          language: isSource ? appState.detectedSourceLanguage?.rawValue
                              : appState.translatedLanguage?.rawValue,
                          content: content)
        } label: {
            Label(label, systemImage: isActive ? "stop.fill" : "speaker.wave.2")
        }
        .font(.system(size: 12, weight: .medium))
        .buttonStyle(.borderless)
        .controlSize(.small)
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .help(label)
        .accessibilityIdentifier(isSource ? "speech-source" : "speech-translation")
    }

    private var footer: some View {
        HStack {
            if let status = appState.statusMessage {
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(footerShortcutHint)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if appState.isRecognizing {
                ProgressView().controlSize(.small)
            } else if appState.isTranslating {
                ProgressView().controlSize(.small)
                Button(String(localized: "common.cancel", defaultValue: "Cancel")) {
                    appState.cancelTranslation()
                }
            } else {
                Button { appState.translate() } label: {
                    Label(String(localized: "translator.translate", defaultValue: "Translate"),
                          systemImage: "sparkles")
                        .frame(minWidth: 74)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(appState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var shortcutDescription: String? {
        appState.globalShortcut?.description
    }

    private var captureShortcutDescription: String? {
        appState.captureShortcut?.description
    }

    private var captureHelp: String {
        guard let captureShortcutDescription else {
            return String(localized: "translator.capture.help",
                          defaultValue: "Drag out a screen region, recognize the text in it, and translate that")
        }
        return String(localized: "translator.capture.help.shortcut",
                      defaultValue: "Drag out a screen region, recognize the text in it, and translate that (\(captureShortcutDescription))")
    }

    private var sourcePlaceholder: String {
        guard let shortcutDescription else {
            return String(localized: "translator.placeholder",
                          defaultValue: "Type some text, or set a global shortcut in Settings first. ⌘⇧V recognizes an image on the clipboard…")
        }
        return String(localized: "translator.placeholder.shortcut",
                      defaultValue: "Type some text, or select text in any app and press \(shortcutDescription). ⌘⇧V recognizes an image on the clipboard…")
    }

    private var accessibilityHint: String {
        guard let shortcutDescription else {
            return String(localized: "translator.accessibility.hint",
                          defaultValue: "Grant Accessibility permission and set a global shortcut to read the selected text in other apps directly.")
        }
        return String(localized: "translator.accessibility.hint.shortcut",
                      defaultValue: "Once Accessibility permission is granted, \(shortcutDescription) reads the selected text in other apps directly.")
    }

    /// 页脚快捷键提示。
    ///
    /// 每个 part 都是一句完整的、可独立翻译的提示；` · ` 只是视觉分隔符，不参与翻译。
    /// 不要把某一句再拆成片段拼装——拼出来的句子没法按语言调整语序。
    private var footerShortcutHint: String {
        var parts: [String] = []
        if let shortcutDescription {
            parts.append(String(localized: "footer.selection.shortcut",
                                defaultValue: "\(shortcutDescription) reads the selection"))
        } else {
            parts.append(String(localized: "footer.selection",
                                defaultValue: "Set a global shortcut to read the selection"))
        }
        if let captureShortcutDescription {
            parts.append(String(localized: "footer.capture",
                                defaultValue: "\(captureShortcutDescription) captures the screen"))
        }
        parts.append(String(localized: "footer.pasteboard",
                            defaultValue: "⌘⇧V recognizes a clipboard image"))
        parts.append(String(localized: "footer.translate", defaultValue: "⌘↩ translates"))
        return parts.joined(separator: " · ")
    }
}
