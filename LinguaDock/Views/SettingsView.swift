import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section(String(localized: "settings.section.service", defaultValue: "Model service")) {
                Picker(String(localized: "settings.service", defaultValue: "Service"),
                       selection: serviceBinding) {
                    ForEach(ServicePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .disabled(isBusy)

                TextField(String(localized: "settings.apiurl", defaultValue: "API URL"),
                          text: $appState.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isBusy)
                    .accessibilityIdentifier("api-base-url")
                Picker(String(localized: "settings.protocol", defaultValue: "Protocol"),
                       selection: $appState.provider) {
                    ForEach(APIProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .disabled(isBusy)
                .accessibilityIdentifier("api-protocol")
                Text(String(localized: "settings.advanced.hint",
                            defaultValue: "Use the API base URL or full endpoint. For regional services, enter the endpoint matching your API key."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField(apiKeyPrompt, text: $appState.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isBusy)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "settings.model", defaultValue: "Model"))
                        Spacer()
                        if !appState.availableModels.isEmpty {
                            Menu(String(localized: "settings.models.choose", defaultValue: "Choose model")) {
                                ForEach(appState.availableModels, id: \.self) { model in
                                    Button(model) { appState.model = model }
                                }
                            }
                            .fixedSize()
                        }
                        Button(String(localized: "settings.models.fetch", defaultValue: "Fetch models")) {
                            appState.fetchModels()
                        }
                        .fixedSize()
                    }
                    TextField(String(localized: "settings.model", defaultValue: "Model"),
                              text: $appState.model)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .help(appState.model)
                        .accessibilityIdentifier("api-model")
                }
                .disabled(isBusy)
                Text(String(localized: "settings.models.hint",
                            defaultValue: "Choose an available text model or enter its ID manually. Some services do not provide a model list."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button(String(localized: "settings.test", defaultValue: "Test translation")) {
                        appState.testConnection()
                    }
                    .disabled(isBusy || appState.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if isBusy {
                        ProgressView().controlSize(.small)
                    }
                    if let status = appState.settingsStatus {
                        Text(status.message)
                            .font(.caption)
                            .foregroundStyle(status.isSuccess ? .green : .secondary)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                }
                Text(String(localized: "settings.test.hint",
                            defaultValue: "Sends “Hello” to the selected model to verify translation. Your API provider may charge for this request."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "settings.section.general", defaultValue: "General")) {
                Toggle(String(localized: "settings.general.hidedock",
                              defaultValue: "Hide the Dock icon when the window is closed"),
                       isOn: $appState.hidesDockWhenClosed)
                Text(String(localized: "settings.general.hidedock.hint",
                            defaultValue: "LinguaDock keeps running either way. The menu bar icon and the shortcuts stay available, and the Dock icon comes back with the window."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                            defaultValue: "The input language is detected automatically. The target language defaults to Simplified Chinese and can be changed in the main window at any time. The current service settings are saved automatically. The API key stays in the macOS Keychain."))
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
        .frame(width: 600, height: 720)
    }

    private var isBusy: Bool { appState.isTestingConnection || appState.isLoadingModels }

    private var serviceBinding: Binding<ServicePreset> {
        Binding(
            get: { appState.servicePreset },
            set: { appState.selectService($0) }
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
