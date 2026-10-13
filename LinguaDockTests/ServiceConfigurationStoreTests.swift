import XCTest
@testable import LinguaDock

final class ServiceConfigurationStoreTests: XCTestCase {
    private func withStore(_ body: (ServiceConfigurationStore, UserDefaults) throws -> Void) throws {
        let name = "LinguaDockTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(ServiceConfigurationStore(defaults: defaults), defaults)
    }

    func testMigratesActiveSlotAndItsIndependentKeyReference() throws {
        try withStore { store, defaults in
            defaults.set(Data(#"[{"id":0,"preset":"ollama","profile":{"provider":"ollama","baseURL":"http://localhost:11434","model":"local-model"}},{"id":4,"preset":"claude","profile":{"provider":"anthropic","baseURL":"https://proxy.example/v1","model":"selected-model"}}]"#.utf8), forKey: "modelSlots.v1")
            defaults.set(4, forKey: "activeModelSlot")
            let current = store.load()
            XCTAssertEqual(current.preset, .claude)
            XCTAssertEqual(current.profile.provider, .anthropic)
            XCTAssertEqual(current.profile.baseURL, "https://proxy.example/v1")
            XCTAssertEqual(current.profile.model, "selected-model")
            XCTAssertEqual(current.keyAccount, "translation-api-key.slot.4.claude")
        }
    }

    func testMigratesLegacySharedKeyReference() throws {
        try withStore { store, defaults in
            defaults.set(Data(#"[{"id":0,"preset":"openAICompatible","profile":{"provider":"openAICompatible","baseURL":"https://example.com/v1","model":"text-model"},"legacyKeyPreset":"openAICompatible"}]"#.utf8), forKey: "modelSlots.v1")
            XCTAssertEqual(store.load().keyAccount, "translation-api-key.openAICompatible")
        }
    }

    func testCurrentConfigurationWinsAfterMigrationAndRestart() throws {
        try withStore { store, defaults in
            let current = SavedServiceConfiguration(preset: .gemini, profile: ServiceProfile(provider: .openAICompatible, baseURL: "https://example.com/v1", model: "new-model"))
            store.save(current)
            defaults.set("old-model", forKey: "model")
            defaults.set(5, forKey: "activeModelSlot")
            XCTAssertEqual(store.load(), current)
        }
    }

    func testOriginalSingleConfigurationMigratesWithoutLosingCustomProtocol() throws {
        try withStore { store, defaults in
            defaults.set("openAICompatible", forKey: "provider")
            defaults.set("https://gateway.example/custom", forKey: "baseURL")
            defaults.set("custom-model", forKey: "model")
            XCTAssertEqual(store.load().profile.baseURL, "https://gateway.example/custom")
            XCTAssertEqual(store.load().profile.model, "custom-model")
            XCTAssertEqual(store.load().keyAccount, "translation-api-key.openAICompatible")
        }
    }
}

@MainActor
final class SingleConfigurationTests: XCTestCase {
    func testEditsSaveOneConfigurationAndChangingServiceClearsCredential() async throws {
        let name = "LinguaDockTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var keys: [String: String] = [:]
        let keyStore = ModelKeyStore(load: { keys[$0] ?? "" }, save: { keys[$1] = $0 }, migrate: {})
        let state = AppState(defaults: defaults, keyStore: keyStore)
        state.selectService(.openai)
        state.baseURL = "https://my-proxy.example/v1"
        state.model = "my-model"
        state.apiKey = "fixture-key"
        let reopened = AppState(defaults: defaults, keyStore: keyStore)
        XCTAssertEqual(reopened.baseURL, state.baseURL)
        XCTAssertEqual(reopened.model, "my-model")
        XCTAssertEqual(reopened.apiKey, "fixture-key")
        state.selectService(.claude)
        XCTAssertEqual(state.apiKey, "")
        state.selectService(.openai)
        XCTAssertEqual(state.apiKey, "")
        XCTAssertEqual(state.model, ServicePreset.openai.model)
        XCTAssertEqual(keys.count, 1)
    }
}
