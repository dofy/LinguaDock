import AppKit
import SwiftUI

/// 主窗口的 NSWindow 配置。
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.identifier = NSUserInterfaceItemIdentifier(AppState.mainWindowIdentifier)
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            DockVisibility.shared.adopt(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // 窗口被收起后再次出现时也要重新登记：SwiftUI 复用同一个内容视图，不会再走
        // makeNSView，而 Dock 图标此刻还是隐藏的。
        DispatchQueue.main.async {
            guard let window = nsView.window, window.isVisible else { return }
            DockVisibility.shared.adopt(window)
        }
    }
}

/// 设置窗口的 NSWindow 配置：只为把窗口交给 `DockVisibility`。
///
/// 没有它的话，accessory 状态下从状态栏打开设置窗口，Dock 图标和菜单栏都不会回来。
struct SettingsWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { adopt(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { adopt(nsView.window) }
    }

    private func adopt(_ window: NSWindow?) {
        guard let window, window.isVisible else { return }
        DockVisibility.shared.adopt(window)
    }
}
