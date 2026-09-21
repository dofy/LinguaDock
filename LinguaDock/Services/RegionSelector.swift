import AppKit

/// 全屏框选器：在每块屏幕上铺一层半透明遮罩，用户拖拽出一个矩形选区。
///
/// 交互对齐系统截图（⌘⇧4）：十字光标、拖拽画框、ESC 取消、松开鼠标完成。
/// 返回选区（AppKit 全局坐标、点）及其所在的 NSScreen；取消或选区过小则返回 nil。
@MainActor
final class RegionSelector {

    // 全程 @MainActor 使用；NSScreen 非 Sendable，标记为 @unchecked 以跨 continuation 传递。
    struct Selection: @unchecked Sendable {
        let rect: CGRect      // AppKit 全局坐标（点）
        let screen: NSScreen
    }

    private var overlays: [OverlayWindow] = []
    private var continuation: CheckedContinuation<Selection?, Never>?

    /// 呈现框选界面并等待用户操作。
    func selectRegion() async -> Selection? {
        await withCheckedContinuation { cont in
            self.continuation = cont
            self.showOverlays()
        }
    }

    private func showOverlays() {
        NSApp.activate(ignoringOtherApps: true)
        for screen in NSScreen.screens {
            let overlay = OverlayWindow(screen: screen)
            overlay.onFinish = { [weak self] rect in
                self?.finish(rect: rect, screen: screen)
            }
            overlay.onCancel = { [weak self] in
                self?.finish(rect: nil, screen: nil)
            }
            overlay.makeKeyAndOrderFront(nil)
            overlays.append(overlay)
        }
    }

    /// 单次 resume + 保证拆除所有遮罩窗与恢复光标。
    private func finish(rect: CGRect?, screen: NSScreen?) {
        guard let cont = continuation else { return }
        continuation = nil

        for overlay in overlays { overlay.orderOut(nil) }
        overlays.removeAll()
        NSCursor.arrow.set()

        // 选区过小视为取消（误触 / 单击）。
        if let rect, let screen, rect.width >= 4, rect.height >= 4 {
            cont.resume(returning: Selection(rect: rect, screen: screen))
        } else {
            cont.resume(returning: nil)
        }
    }
}

// MARK: - 遮罩窗口

private final class OverlayWindow: NSWindow {
    var onFinish: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        ignoresMouseEvents = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let view = SelectionOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.screenOrigin = screen.frame.origin
        view.onFinish = { [weak self] rect in self?.onFinish?(rect) }
        view.onCancel = { [weak self] in self?.onCancel?() }
        contentView = view
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - 选区绘制 + 事件

private final class SelectionOverlayView: NSView {
    var screenOrigin: CGPoint = .zero        // 本屏原点（全局坐标），用于把本地点转全局
    var onFinish: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentRect: CGRect = .zero

    override var acceptsFirstResponder: Bool { true }

    // 多屏时只有一个遮罩窗是 key。默认非 key 窗口的首次点击只用来激活窗口、
    // 不会传成 mouseDown（表现为「第一下圈选无效，得再点一下」）。返回 true
    // 让首次点击直接当作正常鼠标事件，任意屏都能一下开始框选。
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // 十字光标。用 NSTrackingArea + cursorUpdate 而非 addCursorRect：
    // 光标矩形只对 key window 生效，多屏时非 key 屏的遮罩不会显示十字；
    // .activeAlways 的 tracking area 不受 key 状态限制，各屏都能正确显示。
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .cursorUpdate, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func draw(_ dirtyRect: NSRect) {
        // 半透明黑遮罩
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()

        guard currentRect.width > 0, currentRect.height > 0 else { return }
        // 挖空选区（还原为清晰画面）
        NSColor.clear.setFill()
        currentRect.fill(using: .copy)
        // 白色边框
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: currentRect)
        path.lineWidth = 1
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let p = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: min(start.x, p.x),
            y: min(start.y, p.y),
            width: abs(p.x - start.x),
            height: abs(p.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { startPoint = nil }
        // 本地坐标 → 全局坐标（点）
        let global = CGRect(
            x: currentRect.origin.x + screenOrigin.x,
            y: currentRect.origin.y + screenOrigin.y,
            width: currentRect.width,
            height: currentRect.height
        )
        onFinish?(global)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {   // ESC
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}
