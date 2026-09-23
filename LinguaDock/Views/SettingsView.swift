import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section(String(localized: "settings.section.service", defaultValue: "Model service")) {
                Picker(String(localized: "settings.protocol", defaultValue: "Protocol"),
                       selection: providerBinding) {
                    ForEach(APIProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                TextField(String(localized: "settings.apiurl", defaultValue: "API URL"),
                          text: $appState.baseURL)
                    .textFieldStyle(.roundedBorder)
                SecureField(apiKeyPrompt, text: $appState.apiKey)
                    .textFieldStyle(.roundedBorder)
                TextField(String(localized: "settings.model", defaultValue: "Model"),
                          text: $appState.model)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button(String(localized: "settings.test", defaultValue: "Test connection")) {
                        appState.testConnection()
                    }
                    .disabled(appState.isTestingConnection)
                    if appState.isTestingConnection {
                        ProgressView().controlSize(.small)
                    }
                    if let status = appState.settingsStatus {
                        Text(status.message)
                            .font(.caption)
                            .foregroundStyle(status.isSuccess ? .green : .secondary)
                            .lineLimit(2)
                    }
                }
            }

            Section(String(localized: "settings.section.shortcuts", defaultValue: "Shortcuts")) {
                LabeledContent(String(localized: "settings.shortcut.selection",
                                      defaultValue: "Read selected text")) {
                    ShortcutRecorderField(shortcut: $appState.globalShortcut)
                }

                LabeledContent(String(localized: "settings.shortcut.capture",
                                      defaultValue: "Capture the screen and translate")) {
                    ShortcutRecorderField(shortcut: $appState.captureShortcut)
                }

                LabeledContent(String(localized: "settings.shortcut.pasteboard",
                                      defaultValue: "Recognize a clipboard image")) {
                    Text(verbatim: "⌘⇧V")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                LabeledContent(String(localized: "settings.popclip",
                                      defaultValue: "PopClip URL scheme")) {
                    HStack {
                        Text(verbatim: "linguadock://translate?text=…")
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

            Section(String(localized: "settings.section.permissions", defaultValue: "Permissions")) {
                HStack {
                    Label(
                        appState.needsAccessibilityPermission
                            ? String(localized: "settings.permission.accessibility.missing",
                                     defaultValue: "Accessibility not granted")
                            : String(localized: "settings.permission.accessibility.granted",
                                     defaultValue: "Accessibility granted"),
                        systemImage: appState.needsAccessibilityPermission
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.seal.fill"
                    )
                    .foregroundStyle(appState.needsAccessibilityPermission ? .orange : .green)
                    Spacer()
                    if appState.needsAccessibilityPermission {
                        Button(String(localized: "settings.permission.prompt",
                                      defaultValue: "Open the permission prompt")) {
                            appState.requestAccessibilityPermission()
                        }
                    } else {
                        Button(String(localized: "settings.refresh", defaultValue: "Refresh")) {
                            appState.refreshAccessibilityStatus()
                        }
                    }
                }
                HStack {
                    Label(
                        appState.hasScreenRecordingPermission
                            ? String(localized: "settings.permission.screen.granted",
                                     defaultValue: "Screen Recording granted")
                            : String(localized: "settings.permission.screen.missing",
                                     defaultValue: "Screen Recording not granted (needed for screen capture)"),
                        systemImage: appState.hasScreenRecordingPermission
                            ? "checkmark.seal.fill"
                            : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(appState.hasScreenRecordingPermission ? .green : .orange)
                    Spacer()
                    if appState.hasScreenRecordingPermission {
                        Button(String(localized: "settings.refresh", defaultValue: "Refresh")) {
                            appState.refreshScreenRecordingStatus()
                        }
                    } else {
                        Button(String(localized: "settings.opensettings",
                                      defaultValue: "Open System Settings")) {
                            appState.openScreenRecordingSettings()
                        }
                    }
                }
                Text(String(localized: "settings.permission.explain",
                            defaultValue: "Accessibility is used to read the current selection and to send the copy shortcut. Screen Recording is used only to grab the region you drag out, and only when you press the capture shortcut. Text recognition happens on this machine; only its result is sent to the API you configured."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "settings.section.defaults", defaultValue: "Default behavior")) {
                Text(String(localized: "settings.defaults.body",
                            defaultValue: "The input language is detected automatically. The target language defaults to Simplified Chinese and can be changed in the main window at any time. Each protocol's API key is stored separately in the macOS Keychain."))
                    .foregroundStyle(.secondary)
                Text(String(localized: "settings.defaults.ollama",
                            defaultValue: "Ollama defaults: \(APIProvider.ollama.defaultBaseURL) · \(APIProvider.ollama.defaultModel)"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section(String(localized: "settings.section.about", defaultValue: "About")) {
                LabeledContent(String(localized: "settings.about.github",
                                      defaultValue: "GitHub project")) {
                    Link(destination: Self.githubURL) {
                        HStack(spacing: 6) {
                            Text(verbatim: "github.com/dofy/LinguaDock")
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                }

                Text(String(localized: "settings.about.body",
                            defaultValue: "Read the source, the install notes and the changelog there, or file an issue."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            appState.refreshAccessibilityStatus()
            appState.refreshScreenRecordingStatus()
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 560, height: 610)
    }

    private var providerBinding: Binding<APIProvider> {
        Binding(
            get: { appState.provider },
            set: { appState.selectProvider($0) }
        )
    }

    private var apiKeyPrompt: String {
        appState.provider == .ollama
            ? String(localized: "settings.apikey.ollama",
                     defaultValue: "API Key (optional for Ollama)")
            : String(localized: "settings.apikey", defaultValue: "API Key")
    }

    private static let githubURL = URL(string: "https://github.com/dofy/LinguaDock")!
}
