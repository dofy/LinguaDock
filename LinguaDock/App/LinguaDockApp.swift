import SwiftUI

@main
struct LinguaDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup("LinguaDock", id: "translator") {
            TranslatorView()
                .environmentObject(appState)
        }
        .defaultSize(width: 760, height: 620)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("翻译") {
                Button("翻译") { appState.translate() }
                    .keyboardShortcut(.return, modifiers: [.command])
                Button("复制译文") { appState.copyTranslation() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(appState.translatedText.isEmpty)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
