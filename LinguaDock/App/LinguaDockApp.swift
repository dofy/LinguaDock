import SwiftUI

@main
struct LinguaDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // 单例 Window 而非 WindowGroup：WindowGroup 能容纳任意多个窗口，
        // 每个进来的 linguadock:// URL 以及每次启动时的窗口恢复都会再叠一个，
        // 结果是屏幕上堆着好几个一模一样的翻译窗口。
        Window(String(localized: "app.name", defaultValue: "LinguaDock"), id: "translator") {
            MainWindowRoot()
                .environmentObject(appState)
        }
        .defaultSize(width: 760, height: 620)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(String(localized: "menu.translate", defaultValue: "Translate")) {
                Button(String(localized: "menu.translate.run", defaultValue: "Translate")) {
                    appState.translate()
                }
                    .keyboardShortcut(.return, modifiers: [.command])
                Button(String(localized: "menu.copy", defaultValue: "Copy Translation")) {
                    appState.copyTranslation()
                }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(appState.translatedText.isEmpty)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .background(SettingsWindowAccessor())
        }

        // 状态栏图标。窗口全收起后 Dock 图标会消失（见 DockVisibility），这是回到 app 的
        // 主要入口。
        //
        // 图标是 app 图标的 glyph，由 scripts/generate_menubar_icon.swift 直接从
        // AppIcon 抽出来，不是 SF Symbol：一个通用翻译符号在菜单栏里认不出是哪个 app。
        MenuBarExtra {
            MenuBarMenuView()
                .environmentObject(appState)
        } label: {
            Image("MenuBarIcon")
        }
    }
}

/// 主窗口根视图，只为把 `openWindow(id:)` 交给 AppState。
///
/// `showMainWindow()` 在窗口已被关闭时需要重新打开场景，而 `openWindow` 只能从
/// 视图的 environment 取，AppState 自己拿不到。
private struct MainWindowRoot: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        TranslatorView()
            .onAppear {
                appState.reopenMainWindow = { openWindow(id: "translator") }
            }
    }
}
