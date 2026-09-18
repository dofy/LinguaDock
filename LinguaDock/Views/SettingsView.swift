import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var shortcut = KeyboardShortcuts.getShortcut(for: .openTranslator)

    var body: some View {
        Form {
            Section("模型服务") {
                Picker("协议", selection: providerBinding) {
                    ForEach(APIProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                TextField("API URL", text: $appState.baseURL)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key（Ollama 可留空）", text: $appState.apiKey)
                    .textFieldStyle(.roundedBorder)
                TextField("模型", text: $appState.model)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("测试连接") { appState.testConnection() }
                        .disabled(appState.isTestingConnection)
                    if appState.isTestingConnection {
                        ProgressView().controlSize(.small)
                    }
                    if let status = appState.settingsStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(status == "连接成功" ? .green : .secondary)
                            .lineLimit(2)
                    }
                }
            }

            Section("快捷操作") {
                LabeledContent("全局快捷键") {
                    ShortcutRecorderField(shortcut: $shortcut)
                }
                .onChange(of: shortcut) { _, newValue in
                    KeyboardShortcuts.setShortcut(newValue, for: .openTranslator)
                }

                LabeledContent("PopClip URL Scheme") {
                    HStack {
                        Text("linguadock://translate?text=…")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(
                                "linguadock://translate?text=Hello%20world",
                                forType: .string
                            )
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Section("权限") {
                HStack {
                    Label(
                        appState.needsAccessibilityPermission ? "尚未授权辅助功能" : "辅助功能已授权",
                        systemImage: appState.needsAccessibilityPermission
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.seal.fill"
                    )
                    .foregroundStyle(appState.needsAccessibilityPermission ? .orange : .green)
                    Spacer()
                    if appState.needsAccessibilityPermission {
                        Button("打开授权提示") { appState.requestAccessibilityPermission() }
                    } else {
                        Button("刷新") { appState.refreshAccessibilityStatus() }
                    }
                }
                Text("权限只用于读取当前选中文本和发送复制快捷键；文本仅发送到你配置的 API。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("默认行为") {
                Text("中文 → English；其他语言 → 简体中文。API Key 保存在 macOS Keychain。")
                    .foregroundStyle(.secondary)
                Text("Ollama 默认：\(APIProvider.ollama.defaultBaseURL) · \(APIProvider.ollama.defaultModel)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 560, height: 510)
    }

    private var providerBinding: Binding<APIProvider> {
        Binding(
            get: { appState.provider },
            set: { appState.selectProvider($0) }
        )
    }
}
