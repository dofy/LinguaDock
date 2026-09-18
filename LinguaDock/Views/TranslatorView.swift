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

            VStack(spacing: 14) {
                directionBar
                editorCard(
                    title: "原文",
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
            "翻译失败",
            isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { if !$0 { appState.errorMessage = nil } }
            )
        ) {
            Button("好") { appState.errorMessage = nil }
            SettingsLink { Text("打开设置") }
        } message: {
            Text(appState.errorMessage ?? "未知错误")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("BrandIcon")
                .resizable()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("LinguaDock")
                    .font(.system(size: 17, weight: .semibold))
                Text("轻松读懂不同语言")
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
            .help("设置")
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
            Button("授权") { appState.requestAccessibilityPermission() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var directionBar: some View {
        HStack {
            Text("自动检测")
                .frame(maxWidth: .infinity)
            Image(systemName: "arrow.right")
                .accessibilityHidden(true)
            Picker("目标语言", selection: $appState.targetLanguage) {
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
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(text.wrappedValue.count) 字符")
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
                Text("译文")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !appState.translatedText.isEmpty {
                    Button { appState.copyTranslation() } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            ScrollView {
                Text(appState.translatedText.isEmpty ? "译文会出现在这里" : appState.translatedText)
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
            if appState.isTranslating {
                ProgressView().controlSize(.small)
                Button("取消") { appState.cancelTranslation() }
            } else {
                Button { appState.translate() } label: {
                    Label("翻译", systemImage: "sparkles")
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

    private var sourcePlaceholder: String {
        guard let shortcutDescription else {
            return "输入文本，或先在设置中配置全局快捷键…"
        }
        return "输入文本，或在任意 App 中选中文本后按 \(shortcutDescription)…"
    }

    private var accessibilityHint: String {
        guard let shortcutDescription else {
            return "授予辅助功能权限并设置全局快捷键后，可直接读取其他 App 的选中文本。"
        }
        return "授予辅助功能权限后，\(shortcutDescription) 可直接读取其他 App 的选中文本。"
    }

    private var footerShortcutHint: String {
        guard let shortcutDescription else {
            return "设置全局快捷键以读取选中文本 · ⌘↩ 翻译"
        }
        return "\(shortcutDescription) 读取选中文本 · ⌘↩ 翻译"
    }
}
