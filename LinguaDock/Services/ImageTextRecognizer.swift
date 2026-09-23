import CoreGraphics
import Foundation
import Vision

/// 图片文字识别：把截图 / 剪贴板里的图像转成可翻译的纯文本。
enum ImageTextRecognizer {

    enum RecognitionError: LocalizedError {
        case noText

        var errorDescription: String? {
            switch self {
            case .noText:
                return String(localized: "error.ocr.noText",
                              defaultValue: "No text was recognized in the image. Try a sharper region.")
            }
        }
    }

    /// 期望覆盖的识别语言。会与系统实际支持的列表求交后再传给 Vision——
    /// 传入不支持的语言会让 `perform` 直接抛错，一个拼错的 tag 就能废掉整次识别。
    private static let preferredLanguages = [
        "zh-Hans", "zh-Hant", "en-US", "ja-JP", "ko-KR",
        "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "ru-RU",
    ]

    /// 识别图像中的文字，按阅读顺序拼成多行文本。
    /// 识别不到任何文字时抛 `RecognitionError.noText`。
    static func recognizeText(in image: CGImage) async throws -> String {
        let lines = await recognizeLines(in: image)
        let text = normalize(lines: lines)
        guard !text.isEmpty else { throw RecognitionError.noText }
        return text
    }

    /// 把 Vision 的逐行结果整理成一段文本。
    ///
    /// 保留换行而不是拼成一整行：版面里的分行往往是语义分隔（标题 / 列表 / 段落），
    /// 交给模型比在这里猜哪行是硬换行更稳。
    static func normalize(lines: [String]) -> String {
        lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// 运行 Vision 文字识别，返回每行识别结果的最佳候选。
    /// nonisolated：Vision 的回调在后台线程，不应绑定到 MainActor，
    /// 否则 `dispatch_assert_queue` 会因跨 actor 触发 SIGTRAP。
    private static func recognizeLines(in image: CGImage) async -> [String] {
        await withCheckedContinuation { (cont: CheckedContinuation<[String], Never>) in
            // Vision 的 perform 同步阻塞，放到后台队列；回调与 resume 全程在后台线程，
            // 不触及任何 actor 隔离状态。
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { req, _ in
                    let observations = req.results as? [VNRecognizedTextObservation] ?? []
                    cont.resume(returning: observations.compactMap {
                        $0.topCandidates(1).first?.string
                    })
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                // 自动检测语种：翻译场景下截到什么语言都有可能，写死列表会误判。
                request.automaticallyDetectsLanguage = true
                if let supported = try? request.supportedRecognitionLanguages() {
                    request.recognitionLanguages = preferredLanguages.filter(supported.contains)
                }

                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(returning: [])
                }
            }
        }
    }
}
