import AppKit
import SwiftUI

/// 状态栏菜单内容。
///
/// 窗口全收起后 Dock 图标会消失（见 `DockVisibility`），这里就是回到 app 的主要入口，
/// 所以两个取词动作和设置都得在这个菜单里够得着，不能只留「打开」。
struct MenuBarMenuView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button(String(localized: "menubar.open", defaultValue: "Open LinguaDock")) {
            appState.showMainWindow()
        }
        .keyboardShortcut("o", modifiers: [.command])

        Divider()

        Button(String(localized: "menubar.translate.selection",
                      defaultValue: "Translate the Selection")) {
            appState.captureSelectionAndTranslate()
        }

        Button(String(localized: "menubar.translate.capture",
                      defaultValue: "Capture the Screen and Translate")) {
            appState.captureScreenAndTranslate()
        }

        Divider()

        // SettingsLink 而不是 Button + showSettingsWindow:(私有 selector)。accessory 状态下
        // 也能开：设置窗口一出现就会登记自己，把 Dock 图标和菜单栏一起带回来。
        SettingsLink {
            Text(String(localized: "menu.settings", defaultValue: "Settings…"))
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button(String(localized: "menubar.quit", defaultValue: "Quit LinguaDock")) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }
}
