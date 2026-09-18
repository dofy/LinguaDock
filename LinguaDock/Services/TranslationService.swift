import Foundation

enum TranslationServiceError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case server(status: Int, message: String)
    case emptyTranslation

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "API URL 无效，请在设置中检查。"
        case .invalidResponse:
            "服务返回了无法识别的响应。"
        case let .server(status, message):
            "服务请求失败（HTTP \(status)）：\(message)"
        case .emptyTranslation:
            "模型没有返回译文。"
        }
    }
}

struct TranslationService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(_ text: String, using configuration: ProviderConfiguration) async throws -> String {
        let direction = TranslationDirection.detect(for: text)
        let systemPrompt = """
        You are LinguaDock, a professional translation engine. \(direction.prompt)
        Preserve meaning, tone, names, Markdown, paragraph breaks, and code blocks.
        Return only the translated text. Do not explain, label, quote, or comment on it.
        """

        let endpoint: URL
        let body: Data
        switch configuration.provider {
        case .ollama:
            endpoint = try Self.endpoint(baseURL: configuration.baseURL, path: "api/chat")
            body = try JSONEncoder().encode(
                OllamaRequest(
                    model: configuration.model,
                    messages: [
                        .init(role: "system", content: systemPrompt),
                        .init(role: "user", content: text),
                    ],
                    think: false,
                    stream: false,
                    options: .init(temperature: 0.2)
                )
            )
        case .openAICompatible:
            endpoint = try Self.endpoint(baseURL: configuration.baseURL, path: "chat/completions")
            body = try JSONEncoder().encode(
                OpenAIRequest(
                    model: configuration.model,
                    messages: [
                        .init(role: "system", content: systemPrompt),
                        .init(role: "user", content: text),
                    ],
                    temperature: 0.2
                )
            )
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)

        let result: String
        switch configuration.provider {
        case .ollama:
            result = try JSONDecoder().decode(OllamaResponse.self, from: data).message.content
        case .openAICompatible:
            guard let content = try JSONDecoder().decode(OpenAIResponse.self, from: data).choices.first?.message.content
            else { throw TranslationServiceError.invalidResponse }
            result = content
        }

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationServiceError.emptyTranslation }
        return trimmed
    }

    func checkConnection(using configuration: ProviderConfiguration) async throws {
        let path = configuration.provider == .ollama ? "api/tags" : "models"
        var connectionBaseURL = configuration.baseURL
        if configuration.provider == .openAICompatible {
            connectionBaseURL = Self.removingSuffix("chat/completions", from: connectionBaseURL)
        }
        let endpoint = try Self.endpoint(baseURL: connectionBaseURL, path: path)
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        if !configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)
    }

    static func endpoint(baseURL: String, path: String) throws -> URL {
        let trimmedBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: trimmedBase),
              components.scheme != nil,
              components.host != nil
        else { throw TranslationServiceError.invalidBaseURL }

        let currentPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !currentPath.hasSuffix(normalizedPath) {
            components.path = "/" + [currentPath, normalizedPath].filter { !$0.isEmpty }.joined(separator: "/")
        }
        guard let url = components.url else { throw TranslationServiceError.invalidBaseURL }
        return url
    }

    private static func removingSuffix(_ suffix: String, from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard trimmed.lowercased().hasSuffix(suffix.lowercased()) else { return value }
        return String(trimmed.dropLast(suffix.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw TranslationServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let nestedError = object?["error"] as? [String: Any]
            let message = (nestedError?["message"] as? String)
                ?? (object?["error"] as? String)
                ?? String(data: data, encoding: .utf8)
                ?? "未知错误"
            throw TranslationServiceError.server(status: http.statusCode, message: String(message.prefix(300)))
        }
    }
}

private struct ChatMessage: Codable, Sendable {
    let role: String
    let content: String
}

private struct OllamaRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let think: Bool
    let stream: Bool
    let options: Options

    struct Options: Encodable {
        let temperature: Double
    }
}

private struct OllamaResponse: Decodable {
    let message: ChatMessage
}

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

private struct OpenAIResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}
