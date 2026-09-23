import AppKit
import SwiftUI

struct TranslatorView: View {
    @EnvironmentObject private var appState: AppState
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

            VStack(spacing: 14) {
                directionBar
                editorCard(
                    title: String(localized: "translator.source", defaultValue: "Source"),
                    text: $appState.sourceText,
                    placeholder: sourcePlaceholder,
                    editable: true
                )
                resultCard
            }
            .padding(20)

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
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "LinguaDock")
                    .font(.system(size: 17, weight: .semibold))
                Text(String(localized: "app.tagline", defaultValue: "Read any language with ease"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(appState.model, systemImage: "cpu")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(String(localized: "common.settings", defaultValue: "Settings"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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
        HStack(spacing: 2) {
            Button { appState.captureScreenAndTranslate() } label: {
                Label(String(localized: "translator.capture", defaultValue: "Capture the screen"),
                      systemImage: "viewfinder")
            }
            .help(captureHelp)

            Button { appState.translatePasteboardImage() } label: {
                Label(String(localized: "translator.pasteboard",
                             defaultValue: "Recognize a clipboard image"),
                      systemImage: "photo.on.rectangle")
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .help(String(localized: "translator.pasteboard.help",
                         defaultValue: "Recognize the image on the clipboard and translate it (⌘⇧V)"))
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 12, weight: .medium))
        .buttonStyle(.borderless)
        .controlSize(.small)
        .disabled(appState.isRecognizing)
    }

    private var directionBar: some View {
        HStack {
            Text(String(localized: "translator.detect", defaultValue: "Detect language"))
                .frame(maxWidth: .infinity)
            Image(systemName: "arrow.right")
                .accessibilityHidden(true)
            Picker(String(localized: "translator.target", defaultValue: "Target language"),
                   selection: $appState.targetLanguage) {
                ForEach(TargetLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
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
                Spacer()
                if editable {
                    imageInputButtons
                }
                Text(String(localized: "translator.charcount",
                            defaultValue: "\(text.wrappedValue.count) characters"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
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
        .padding(.vertical, 14)
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
