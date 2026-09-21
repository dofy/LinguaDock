import AppKit
import CoreGraphics
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
    /// 截屏失败后才亮的引导横幅，不在每次启动就打扰没用过截屏识别的人。
    @Published var needsScreenRecordingPermission = false
    /// 「屏幕录制」的真实授权状态，设置页据此显示。
    @Published var hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    /// 图片 OCR 进行中（截屏识别 / 剪贴板识图共用）。
    @Published var isRecognizing = false

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
    @Published var captureShortcut: KeyboardShortcuts.Shortcut? {
        didSet {
            guard captureShortcut != oldValue else { return }
            KeyboardShortcuts.setShortcut(captureShortcut, for: .captureAndTranslate)
        }
    }

    private let defaults = UserDefaults.standard
    private let translationService = TranslationService()
    private var translationTask: Task<Void, Never>?
    private var accessibilityRefreshTask: Task<Void, Never>?
    private var hotkeyConfigured = false
    private var pasteMonitor: Any?
    /// 框选 / 识别进行中，挡住重复触发：热键按两下会叠两层遮罩，后一层拆不掉。
    private var captureInFlight = false

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
        captureShortcut = KeyboardShortcuts.getShortcut(for: .captureAndTranslate)
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
        KeyboardShortcuts.onKeyUp(for: .captureAndTranslate) {
            Task { @MainActor in
                AppState.shared.captureScreenAndTranslate()
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

    // MARK: - 图片 → 文字 → 翻译

    /// 框选屏幕 → 截图 → OCR → 翻译。
    func captureScreenAndTranslate() {
        guard !captureInFlight else { return }
        captureInFlight = true

        Task { @MainActor in
            defer { captureInFlight = false }

            // 先把自己的窗口收起来：RegionSelector 会激活 LinguaDock，主窗口一旦抢到
            // 前台就挡住用户想截的内容，还会被一起拍进图里。
            let ownWindows = NSApp.windows.filter(\.isVisible)
            ownWindows.forEach { $0.orderOut(nil) }

            guard let selection = await RegionSelector().selectRegion() else {
                // 取消：把刚收起来的窗口放回去，否则看起来像 app 自己退了。
                ownWindows.forEach { $0.makeKeyAndOrderFront(nil) }
                return
            }

            do {
                let image = try await ScreenCapturer.capture(
                    rect: selection.rect,
                    on: selection.screen
                )
                needsScreenRecordingPermission = false
                hasScreenRecordingPermission = true
                showMainWindow()
                await recognizeAndTranslate(image)
            } catch {
                if case ScreenCapturer.CaptureError.permissionDenied = error {
                    needsScreenRecordingPermission = true
                    hasScreenRecordingPermission = false
                }
                showMainWindow()
                statusMessage = error.localizedDescription
            }
        }
    }

    /// 读剪贴板里的图片 → OCR → 翻译。
    func translatePasteboardImage() {
        guard !captureInFlight else { return }
        captureInFlight = true

        Task { @MainActor in
            defer { captureInFlight = false }
            showMainWindow()
            do {
                await recognizeAndTranslate(try PasteboardImage.read())
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    /// 识别出的文字填进原文框，然后走正常翻译流程。
    private func recognizeAndTranslate(_ image: CGImage) async {
        isRecognizing = true
        errorMessage = nil
        statusMessage = "正在识别图片文字…"
        defer { isRecognizing = false }

        do {
            sourceText = try await ImageTextRecognizer.recognizeText(in: image)
            translate()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    /// ⌘V：剪贴板里只有图片（没有文字）时，把粘贴变成识图。
    ///
    /// 为什么用本地事件监听而不是 SwiftUI 的 `onPasteCommand`：原文框是 TextEditor，
    /// 底层 NSTextView 在响应链里自己就处理掉了 ⌘V，外层视图的 paste 处理器收不到。
    /// 只在主窗口是 key 窗口时接管，设置窗口里的 ⌘V 保持原样。
    func installPasteMonitor() {
        guard pasteMonitor == nil else { return }
        pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "v",
                  NSApp.keyWindow?.identifier?.rawValue == Self.mainWindowIdentifier,
                  PasteboardImage.isAvailable(),
                  !PasteboardImage.hasText()
            else { return event }

            translatePasteboardImage()
            // 吃掉事件：TextEditor 拿图片什么也做不了，透传只会表现为「按了没反应」。
            return nil
        }
    }

    func openScreenRecordingSettings() {
        ScreenCapturer.openScreenRecordingSettings()
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

    /// 重读「屏幕录制」授权状态。
    ///
    /// 授权是在系统设置里改的，app 自己收不到通知，所以在设置页出现和 app 重新
    /// 激活时各查一次。已授权就顺手把失败横幅撤掉。
    func refreshScreenRecordingStatus() {
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
        if hasScreenRecordingPermission {
            needsScreenRecordingPermission = false
        }
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

    static let mainWindowIdentifier = "LinguaDock.Main"

    /// 重新打开主窗口场景。由主窗口的根视图注入 `openWindow(id:)`。
    ///
    /// 主窗口是单例 `Window` 场景，关掉后窗口对象就不存在了，而 app 不随最后一个
    /// 窗口退出，所以只靠 `NSApp.windows` 查找会找不到目标、热键和 URL 静默失效。
    /// 存下 `openWindow` 动作作为兜底：闭包在窗口关闭后依然有效。
    var reopenMainWindow: (() -> Void)?

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == Self.mainWindowIdentifier }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first(where: { $0.title == "LinguaDock" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            reopenMainWindow?()
        }
    }
}
