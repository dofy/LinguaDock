import Foundation

enum APIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case ollama
    case openAICompatible
    case anthropic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ollama: "Ollama"
        case .openAICompatible: "OpenAI Compatible"
        case .anthropic: "Anthropic Messages"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .ollama: "http://localhost:11434"
        case .openAICompatible: "https://api.openai.com/v1"
        case .anthropic: "https://api.anthropic.com/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .ollama: "qwen3.5:9b"
        case .openAICompatible: "gpt-5-mini"
        case .anthropic: ""
        }
    }
}

struct ProviderConfiguration: Equatable, Sendable {
    var provider: APIProvider
    var baseURL: String
    var apiKey: String
    var model: String
    var targetLanguage: TargetLanguage
}

/// Presets select defaults; the wire protocol remains an independent detail.
/// The custom raw value preserves the existing OpenAI-compatible Keychain account.
enum ServicePreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case ollama, openai, deepseek, gemini, qwen, openrouter, claude
    case custom = "openAICompatible"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .ollama: "Ollama"
        case .openai: "OpenAI"
        case .deepseek: "DeepSeek"
        case .gemini: "Gemini"
        case .qwen: "Qwen / DashScope"
        case .openrouter: "OpenRouter"
        case .claude: "Claude"
        case .custom: String(localized: "settings.service.custom", defaultValue: "Custom")
        }
    }
    var provider: APIProvider {
        switch self {
        case .ollama: .ollama
        case .claude: .anthropic
        default: .openAICompatible
        }
    }
    var baseURL: String {
        switch self {
        case .ollama: APIProvider.ollama.defaultBaseURL
        case .openai, .custom: APIProvider.openAICompatible.defaultBaseURL
        case .deepseek: "https://api.deepseek.com/v1"
        case .gemini: "https://generativelanguage.googleapis.com/v1beta/openai"
        case .qwen: "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .openrouter: "https://openrouter.ai/api/v1"
        case .claude: APIProvider.anthropic.defaultBaseURL
        }
    }
    var model: String {
        switch self {
        case .ollama: APIProvider.ollama.defaultModel
        case .openai: APIProvider.openAICompatible.defaultModel
        default: "" // Fetch the account's available models rather than hardcode aging IDs.
        }
    }
}

struct ServiceProfile: Codable, Equatable, Sendable {
    var provider: APIProvider
    var baseURL: String
    var model: String
}

/// Only the current configuration is saved. Old entries are read solely for migration.
struct SavedServiceConfiguration: Codable, Equatable, Sendable {
    static let currentKeyAccount = "translation-api-key.current"
    var preset: ServicePreset
    var profile: ServiceProfile
    var keyAccount: String = Self.currentKeyAccount
}

struct ServiceConfigurationStore {
    let defaults: UserDefaults

    func load() -> SavedServiceConfiguration {
        if let data = defaults.data(forKey: "currentServiceConfiguration.v1"),
           let current = try? JSONDecoder().decode(SavedServiceConfiguration.self, from: data) {
            return current
        }
        let current: SavedServiceConfiguration
        if let data = defaults.data(forKey: "modelSlots.v1"),
           let slots = try? JSONDecoder().decode([LegacySlot].self, from: data),
           let slot = slots.first(where: { $0.id == min(max(defaults.integer(forKey: "activeModelSlot"), 0), 5) }) {
            let account = slot.legacyKeyPreset == slot.preset
                ? "translation-api-key.\(slot.preset.rawValue)"
                : "translation-api-key.slot.\(slot.id).\(slot.preset.rawValue)"
            current = SavedServiceConfiguration(preset: slot.preset,
                profile: slot.profile ?? ServiceProfile(provider: slot.preset.provider, baseURL: slot.preset.baseURL, model: ""),
                keyAccount: account)
        } else {
            let provider = defaults.string(forKey: "provider").flatMap(APIProvider.init(rawValue:)) ?? .ollama
            let preset = defaults.string(forKey: "servicePreset").flatMap(ServicePreset.init(rawValue:))
                ?? (provider == .ollama ? .ollama : .custom)
            let profile = defaults.data(forKey: "serviceProfile.\(preset.rawValue)")
                .flatMap { try? JSONDecoder().decode(ServiceProfile.self, from: $0) }
                ?? ServiceProfile(provider: provider,
                    baseURL: defaults.string(forKey: "baseURL") ?? preset.baseURL,
                    model: defaults.string(forKey: "model") ?? preset.model)
            current = SavedServiceConfiguration(preset: preset, profile: profile,
                                                 keyAccount: "translation-api-key.\(preset.rawValue)")
        }
        save(current)
        return current
    }

    func save(_ current: SavedServiceConfiguration) {
        guard let data = try? JSONEncoder().encode(current) else { return }
        defaults.set(data, forKey: "currentServiceConfiguration.v1")
    }

    private struct LegacySlot: Decodable {
        let id: Int
        let preset: ServicePreset
        let profile: ServiceProfile?
        let legacyKeyPreset: ServicePreset?
    }
}
