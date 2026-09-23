import AppKit
import CoreGraphics
import ScreenCaptureKit

/// 屏幕区域截图：用 ScreenCaptureKit 截取整块显示器，再按像素裁剪到选区。
///
/// 采用「截全屏 + 裁剪」而非 SCContentFilter 的 sourceRect，
/// 以规避 AppKit（左下原点 / 点）与 CoreGraphics（左上原点 / 像素）之间的坐标转换歧义，
/// 并天然兼容多显示器与 Retina 缩放。
@MainActor
enum ScreenCapturer {

    enum CaptureError: LocalizedError {
        case noDisplay        // 找不到匹配的 SCDisplay
        case permissionDenied // 未授予「屏幕录制」权限
        case cropFailed       // 裁剪失败（选区超出图像等）

        var errorDescription: String? {
            switch self {
            case .noDisplay:
                return String(localized: "error.capture.noDisplay",
                              defaultValue: "The display holding that selection couldn’t be found. Try again.")
            case .permissionDenied:
                return String(localized: "error.capture.permissionDenied",
                              defaultValue: "Screen capture needs Screen Recording permission. Allow LinguaDock in System Settings.")
            case .cropFailed:
                return String(localized: "error.capture.cropFailed",
                              defaultValue: "Cropping the capture failed. Drag out the region again.")
            }
        }
    }

    /// 截取 `screen` 上 `rect`（AppKit 全局坐标、点）对应的区域，返回裁剪后的 CGImage。
    /// - Parameters:
    ///   - rect: 选区，AppKit 全局坐标系（原点在主屏左下，单位为点）。
    ///   - screen: 选区所在的 NSScreen。
    static func capture(rect: CGRect, on screen: NSScreen) async throws -> CGImage {
        // 找到对应的 SCDisplay。SCShareableContent 首次调用会触发系统「屏幕录制」授权弹窗；
        // 未授权时会抛错 → 归一为 permissionDenied。
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            )
        } catch {
            throw CaptureError.permissionDenied
        }

        guard let displayID = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? CGDirectDisplayID,
              let display = content.displays.first(where: { $0.displayID == displayID })
        else {
            throw CaptureError.noDisplay
        }

        let scale = screen.backingScaleFactor
        let config = SCStreamConfiguration()
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = false
        config.scalesToFit = false

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let full = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        // 将 AppKit 全局矩形转换为「相对该屏、左上原点、像素」的裁剪矩形。
        let frame = screen.frame
        let localX = rect.origin.x - frame.origin.x
        // 翻转 Y：AppKit 原点在左下，图像原点在左上。
        let localYTop = frame.height - ((rect.origin.y - frame.origin.y) + rect.height)
        let pixelRect = CGRect(
            x: localX * scale,
            y: localYTop * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).integral

        // 约束在图像范围内。
        let bounds = CGRect(x: 0, y: 0, width: full.width, height: full.height)
        let clamped = pixelRect.intersection(bounds)
        guard !clamped.isNull, clamped.width >= 1, clamped.height >= 1,
              let cropped = full.cropping(to: clamped)
        else {
            throw CaptureError.cropFailed
        }
        return cropped
    }

    /// 打开系统设置的「屏幕录制」页。授权与否由系统控制，app 只能引导。
    static func openScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
