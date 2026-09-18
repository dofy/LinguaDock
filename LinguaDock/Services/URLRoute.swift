import Foundation

enum URLRoute: Equatable {
    case translate(String)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "linguadock",
              url.host?.lowercased() == "translate",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let text = components.queryItems?.first(where: { $0.name == "text" })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return nil }
        self = .translate(text)
    }
}
