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
    @Published var apiKey: String {
        didSet {
            do {
                try APIKeyStore.save(apiKey)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    @Published var settingsStatus: String?
    @Published var isTestingConnection = false

    var direction: TranslationDirection { .detect(for: sourceText) }

    private let defaults = UserDefaults.standard
    private let translationService = TranslationService()
    private var translationTask: Task<Void, Never>?
    private var hotkeyConfigured = false

    private enum Keys {
        static let provider = "provider"
        static let baseURL = "baseURL"
        static let model = "model"
    }

    private init() {
        let storedProvider = UserDefaults.standard.string(forKey: Keys.provider)
            .flatMap(APIProvider.init(rawValue:)) ?? .ollama
        provider = storedProvider
        baseURL = UserDefaults.standard.string(forKey: Keys.baseURL) ?? storedProvider.defaultBaseURL
        model = UserDefaults.standard.string(forKey: Keys.model) ?? storedProvider.defaultModel
        apiKey = APIKeyStore.load()
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
        settingsStatus = nil
    }

    func captureSelectionAndTranslate() {
        statusMessage = "正在读取选中文本…"
        Task { @MainActor in
            let selected = await SelectedTextReader.readSelectedText()
            needsAccessibilityPermission = !SelectedTextReader.isTrusted
            showMainWindow()

            guard let selected, !selected.isEmpty else {
                statusMessage = "没有读到选中文本。可粘贴文本，或授予辅助功能权限后重试。"
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
            model: model.trimmingCharacters(in: .whitespacesAndNewlines)
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

    func swapText() {
        guard !translatedText.isEmpty else { return }
        (sourceText, translatedText) = (translatedText, sourceText)
    }

    func copyTranslation() {
        guard !translatedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
        statusMessage = "译文已复制"
    }

    func requestAccessibilityPermission() {
        SelectedTextReader.requestAccessibilityPermission()
        needsAccessibilityPermission = !SelectedTextReader.isTrusted
    }

    func refreshAccessibilityStatus() {
        needsAccessibilityPermission = !SelectedTextReader.isTrusted
    }

    func testConnection() {
        guard !isTestingConnection else { return }
        isTestingConnection = true
        settingsStatus = "正在连接…"
        let configuration = ProviderConfiguration(
            provider: provider,
            baseURL: baseURL,
            apiKey: apiKey,
            model: model
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
