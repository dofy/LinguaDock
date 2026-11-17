import AppKit
import SwiftUI

extension View {
    /// 让这个视图底层的 NSScrollView 始终用浮动（overlay）滚动条。
    ///
    /// 接了鼠标时系统的「显示滚动条：自动」会切到 legacy 样式：TextEditor 右侧常驻一条
    /// 不透明的滚动槽，即使没有内容可滚。overlay 样式只在滚动时出现一条细滑块，不占宽度。
    func overlayScrollers() -> some View {
        background(OverlayScrollerConfigurator())
    }
}

private struct OverlayScrollerConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = MarkerView()
        view.coordinator = context.coordinator
        context.coordinator.marker = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { context.coordinator.apply() }
    }

    /// makeNSView 时标记视图还没布局，bounds 为零，找不到滚动视图；
    /// 等它真正布局（以及窗口尺寸变化）时再找。
    private final class MarkerView: NSView {
        weak var coordinator: Coordinator?

        override func layout() {
            super.layout()
            DispatchQueue.main.async { [weak self] in self?.coordinator?.apply() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.coordinator?.apply() }
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var marker: NSView?
        private weak var scrollView: NSScrollView?

        override init() {
            super.init()
            // 鼠标插拔或改系统设置时 AppKit 会把所有滚动视图重置成新的首选样式，
            // 所以要在它之后再改回来。selector 形式的观察者在 dealloc 时自动注销。
            NotificationCenter.default.addObserver(
                self, selector: #selector(preferredScrollerStyleDidChange),
                name: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil
            )
        }

        @objc private func preferredScrollerStyleDidChange() {
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        func apply() {
            if scrollView?.window == nil { scrollView = findScrollView() }
            guard let scrollView else { return }
            if scrollView.scrollerStyle != .overlay { scrollView.scrollerStyle = .overlay }
            if !scrollView.autohidesScrollers { scrollView.autohidesScrollers = true }
        }

        /// background 视图和 SwiftUI 包出来的 NSScrollView 是兄弟关系而不是父子，
        /// 所以从标记视图逐级向上，找覆盖标记中心点的那个滚动视图。
        private func findScrollView() -> NSScrollView? {
            guard let marker, marker.window != nil, !marker.bounds.isEmpty else { return nil }
            let center = marker.convert(NSPoint(x: marker.bounds.midX, y: marker.bounds.midY), to: nil)
            var ancestor = marker.superview
            while let current = ancestor {
                if let found = Self.scrollView(in: current, containing: center, excluding: marker) {
                    return found
                }
                ancestor = current.superview
            }
            return nil
        }

        private static func scrollView(in view: NSView, containing point: NSPoint,
                                       excluding marker: NSView) -> NSScrollView? {
            for subview in view.subviews where subview !== marker {
                if let scrollView = subview as? NSScrollView,
                   scrollView.convert(scrollView.bounds, to: nil).contains(point) {
                    return scrollView
                }
                if let found = scrollView(in: subview, containing: point, excluding: marker) {
                    return found
                }
            }
            return nil
        }
    }
}
