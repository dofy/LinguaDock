import AppKit
import CoreGraphics
import UniformTypeIdentifiers

/// 从剪贴板取图：截图工具、浏览器、Finder 里拷的图片都走这里。
enum PasteboardImage {

    enum PasteError: LocalizedError {
        case noImage

        var errorDescription: String? {
            switch self {
            case .noImage:
                return String(localized: "error.paste.noImage",
                              defaultValue: "There is no image on the clipboard. Take a screenshot or copy an image first, then press ⌘⇧V.")
            }
        }
    }

    /// 只接受图片文件的 URL，避免把随手拷的文本文件也当成图读进来。
    ///
    /// 用计算属性而非 static let：字典值类型是 Any，Swift 6 下不算 Sendable，
    /// 存成全局常量会被判成「可能共享可变状态」。每次现造一份，零成本。
    private static var urlOptions: [NSPasteboard.ReadingOptionKey: Any] {
        [.urlReadingContentsConformToTypes: [UTType.image.identifier]]
    }

    /// 剪贴板里是否有可识别的图片。
    static func isAvailable(in pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.canReadObject(forClasses: [NSImage.self], options: nil)
            || pasteboard.canReadObject(forClasses: [NSURL.self], options: urlOptions)
    }

    /// 剪贴板里是否有纯文本。
    ///
    /// 用来区分「⌘V 该粘文字还是该识图」：同时带文字和图片时（比如从网页复制的
    /// 图文混排），文字是用户更可能想要的，识图交给显式的 ⌘⇧V。
    static func hasText(in pasteboard: NSPasteboard = .general) -> Bool {
        guard let string = pasteboard.string(forType: .string) else { return false }
        return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 读出剪贴板里的图片。
    static func read(from pasteboard: NSPasteboard = .general) throws -> CGImage {
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?
            .compactMap({ $0 as? NSImage })
            .first,
           let cgImage = cgImage(from: image) {
            return cgImage
        }

        if let url = pasteboard.readObjects(forClasses: [NSURL.self], options: urlOptions)?
            .compactMap({ $0 as? URL })
            .first,
           let image = NSImage(contentsOf: url),
           let cgImage = cgImage(from: image) {
            return cgImage
        }

        throw PasteError.noImage
    }

    /// 取 NSImage 里像素最多的那个表示。
    ///
    /// `cgImage(forProposedRect:)` 会按 NSImage 的「点」尺寸给图，Retina 截图取到的
    /// 是降采样后的版本，OCR 精度白扔一半。位图表示里直接挑最大的那张。
    private static func cgImage(from image: NSImage) -> CGImage? {
        let bitmaps = image.representations.compactMap { $0 as? NSBitmapImageRep }
        if let largest = bitmaps.max(by: { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }),
           let cgImage = largest.cgImage {
            return cgImage
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
