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
                    placeholder: "输入文本，或在任意 App 中选中文本后按 ⇧⌘T…",
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
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("LinguaDock")
                    .font(.headline)
                Text("本地优先的 AI 翻译")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(appState.model, systemImage: "cpu")
                .font(.caption)
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
            Text("授予辅助功能权限后，⇧⌘T 可直接读取其他 App 的选中文本。")
                .font(.callout)
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
            Text(appState.direction.sourceLabel)
                .frame(maxWidth: .infinity)
            Button { appState.swapText() } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)
            .disabled(appState.translatedText.isEmpty)
            Text(appState.direction.targetLabel)
                .frame(maxWidth: .infinity)
        }
        .font(.subheadline.weight(.semibold))
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
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(text.wrappedValue.count) 字符")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
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
                Text("译文").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if !appState.translatedText.isEmpty {
                    Button { appState.copyTranslation() } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            ScrollView {
                Text(appState.translatedText.isEmpty ? "译文会出现在这里" : appState.translatedText)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("⇧⌘T 读取选中文本 · ⌘↩ 翻译")
                    .font(.caption)
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
}
