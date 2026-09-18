import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published var isTranslating = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var needsAccessibilityPermission = !SelectedTextReader.isTrusted

    @Published var provider: APIProvider {
        didSet { defaults.set(provider.rawValue, forKey: Keys.provider) }
    }
    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Keys.baseURL) }
    }
    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }
    @Published var targetLanguage: TargetLanguage {
        didSet { defaults.set(targetLanguage.rawValue, forKey: Keys.targetLanguage) }
    }
    @Published var apiKey: String {
        didSet {
            guard apiKey != oldValue else { return }
            do {
                try APIKeyStore.save(apiKey, for: provider)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    @Published var settingsStatus: String?
    @Published var isTestingConnection = false
    @Published var globalShortcut: KeyboardShortcuts.Shortcut? {
        didSet {
            guard globalShortcut != oldValue else { return }
            KeyboardShortcuts.setShortcut(globalShortcut, for: .openTranslator)
        }
    }

    private let defaults = UserDefaults.standard
    private let translationService = TranslationService()
    private var translationTask: Task<Void, Never>?
    private var accessibilityRefreshTask: Task<Void, Never>?
    private var hotkeyConfigured = false

    private enum Keys {
        static let provider = "provider"
        static let baseURL = "baseURL"
        static let model = "model"
        static let targetLanguage = "targetLanguage"
    }

    private init() {
        let migrationError: Error?
        do {
            try APIKeyStore.migrateLegacyKeyToOpenAICompatible()
            migrationError = nil
        } catch {
            migrationError = error
        }

        let storedProvider = UserDefaults.standard.string(forKey: Keys.provider)
            .flatMap(APIProvider.init(rawValue:)) ?? .ollama
        provider = storedProvider
        baseURL = UserDefaults.standard.string(forKey: Keys.baseURL) ?? storedProvider.defaultBaseURL
        model = UserDefaults.standard.string(forKey: Keys.model) ?? storedProvider.defaultModel
        targetLanguage = UserDefaults.standard.string(forKey: Keys.targetLanguage)
            .flatMap(TargetLanguage.init(rawValue:)) ?? .default
        apiKey = APIKeyStore.load(for: storedProvider)
        globalShortcut = KeyboardShortcuts.getShortcut(for: .openTranslator)
        if let migrationError {
            errorMessage = migrationError.localizedDescription
        }
    }

    func configureHotkey() {
        guard !hotkeyConfigured else { return }
        KeyboardShortcuts.onKeyUp(for: .openTranslator) {
            Task { @MainActor in
                AppState.shared.captureSelectionAndTranslate()
            }
        }
        hotkeyConfigured = true
    }

    func selectProvider(_ newProvider: APIProvider) {
        guard provider != newProvider else { return }
        provider = newProvider
        baseURL = newProvider.defaultBaseURL
        model = newProvider.defaultModel
        apiKey = APIKeyStore.load(for: newProvider)
        settingsStatus = nil
    }

    func captureSelectionAndTranslate() {
        refreshAccessibilityStatus()
        guard !needsAccessibilityPermission else {
            showMainWindow()
            statusMessage = "尚未获得辅助功能权限。请先点击授权，然后在系统设置中允许 LinguaDock。"
            return
        }

        statusMessage = "正在读取选中文本…"
        Task { @MainActor in
            let selected = await SelectedTextReader.readSelectedText()
            needsAccessibilityPermission = !SelectedTextReader.isTrusted
            showMainWindow()

            guard let selected, !selected.isEmpty else {
                statusMessage = "没有读到选中文本。请确认原应用中已有选区，然后重试。"
                return
            }
            sourceText = selected
            translate()
        }
    }

    func handle(_ route: URLRoute) {
        switch route {
        case let .translate(text):
            sourceText = text
            showMainWindow()
            translate()
        }
    }

    func translate() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusMessage = "先输入或选中要翻译的文本。"
            return
        }

        let configuration = ProviderConfiguration(
            provider: provider,
            baseURL: baseURL,
            apiKey: apiKey,
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            targetLanguage: targetLanguage
        )
        guard !configuration.model.isEmpty else {
            errorMessage = "请先在设置中填写模型名称。"
            return
        }

        translationTask?.cancel()
        isTranslating = true
        errorMessage = nil
        statusMessage = "正在用 \(configuration.model) 翻译…"

        translationTask = Task { @MainActor in
            do {
                let result = try await translationService.translate(text, using: configuration)
                try Task.checkCancellation()
                translatedText = result
                statusMessage = "翻译完成"
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
            isTranslating = false
        }
    }

    func cancelTranslation() {
        translationTask?.cancel()
        translationTask = nil
        isTranslating = false
        statusMessage = "已取消"
    }

    func copyTranslation() {
        guard !translatedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
        statusMessage = "译文已复制"
    }

    func requestAccessibilityPermission() {
        SelectedTextReader.requestAccessibilityPermission()
        monitorAccessibilityPermission()
    }

    func refreshAccessibilityStatus() {
        needsAccessibilityPermission = !SelectedTextReader.isTrusted
    }

    private func monitorAccessibilityPermission() {
        accessibilityRefreshTask?.cancel()
        accessibilityRefreshTask = Task { @MainActor [weak self] in
            // The system permission is changed outside LinguaDock. Poll briefly so
            // the banner disappears even before the app becomes active again.
            for _ in 0..<120 {
                guard let self, !Task.isCancelled else { return }
                refreshAccessibilityStatus()
                if !needsAccessibilityPermission { return }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func testConnection() {
        guard !isTestingConnection else { return }
        isTestingConnection = true
        settingsStatus = "正在连接…"
        let configuration = ProviderConfiguration(
            provider: provider,
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            targetLanguage: targetLanguage
        )
        Task { @MainActor in
            do {
                try await translationService.checkConnection(using: configuration)
                settingsStatus = "连接成功"
            } catch {
                settingsStatus = error.localizedDescription
            }
            isTestingConnection = false
        }
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "LinguaDock.Main" }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first(where: { $0.title == "LinguaDock" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
