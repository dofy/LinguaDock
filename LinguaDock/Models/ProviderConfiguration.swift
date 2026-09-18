import Foundation

enum APIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case ollama
    case openAICompatible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ollama: "Ollama"
        case .openAICompatible: "OpenAI Compatible"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .ollama: "http://localhost:11434"
        case .openAICompatible: "https://api.openai.com/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .ollama: "qwen3.5:9b"
        case .openAICompatible: "gpt-5-mini"
        }
    }
}

struct ProviderConfiguration: Equatable, Sendable {
    var provider: APIProvider
    var baseURL: String
    var apiKey: String
    var model: String
}
