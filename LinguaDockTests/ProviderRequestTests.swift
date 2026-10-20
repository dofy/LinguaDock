import XCTest
@testable import LinguaDock

private final class ProviderURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, body) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                           httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class ProviderRequestTests: XCTestCase, @unchecked Sendable {
    @MainActor
    func testSmartDirectionIsUsedByTheRequestAndFixedTargetOverridesIt() async throws {
        let name = "LinguaDockTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let keys = ModelKeyStore(load: { _ in "fixture-key" }, save: { _, _ in }, migrate: {})
        let state = AppState(defaults: defaults, keyStore: keys, translationService: service())
        state.selectService(.openai)
        state.baseURL = "https://example.com/v1"
        state.model = "fixture-model"
        state.sourceText = "请先确认付款是否成功，再决定是否重新扣款。"
        var prompts: [String] = []
        ProviderURLProtocol.handler = { request in
            let messages = try XCTUnwrap(self.body(request)["messages"] as? [[String: String]])
            prompts.append(try XCTUnwrap(messages.first?["content"]))
            return (200, #"{"choices":[{"message":{"content":"translated"},"finish_reason":"stop"}]}"#)
        }
        for smart in [true, false] {
            state.smartTranslationEnabled = smart
            state.translate()
            for _ in 0..<100 where state.isTranslating {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertFalse(state.isTranslating)
            XCTAssertNil(state.errorMessage)
            XCTAssertEqual(state.translatedText, "translated")
        }
        XCTAssertEqual(prompts.count, 2)
        XCTAssertTrue(prompts.first?.contains("precise English") == true)
        XCTAssertTrue(prompts.last?.contains("precise Simplified Chinese") == true)
    }

    private func service() -> TranslationService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProviderURLProtocol.self]
        return TranslationService(session: URLSession(configuration: configuration))
    }

    private func configuration(_ provider: APIProvider, baseURL: String = "https://example.com/v1") -> ProviderConfiguration {
        ProviderConfiguration(provider: provider, baseURL: baseURL, apiKey: " test-key ",
                              model: "text-model", targetLanguage: .simplifiedChinese)
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody
        if data == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var bytes = [UInt8](repeating: 0, count: 4096)
            var result = Data()
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes, maxLength: bytes.count)
                if count <= 0 { break }
                result.append(contentsOf: bytes.prefix(count))
            }
            data = result
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data)) as? [String: Any])
    }

    func testOpenAIRequestOmitsSamplingAndReadsTextBlocks() async throws {
        ProviderURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            let payload = try self.body(request)
            XCTAssertNil(payload["temperature"])
            XCTAssertEqual(payload["stream"] as? Bool, false)
            return (200, #"{"choices":[{"message":{"content":[{"type":"thinking","text":"hidden"},{"type":"text","text":"translated"}]},"finish_reason":"stop"}]}"#)
        }
        let result = try await service().translate("Hello", using: configuration(.openAICompatible))
        XCTAssertEqual(result, "translated")
    }

    func testClaudeUsesNativeAuthenticationAndTopLevelSystem() async throws {
        ProviderURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/messages")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let payload = try self.body(request)
            XCTAssertNotNil(payload["system"] as? String)
            XCTAssertEqual(payload["max_tokens"] as? Int, 8192)
            let messages = try XCTUnwrap(payload["messages"] as? [[String: String]])
            XCTAssertEqual(messages.map { $0["role"] }, ["user"])
            return (200, #"{"content":[{"type":"thinking","thinking":"hidden"},{"type":"text","text":"translated"}],"stop_reason":"end_turn"}"#)
        }
        let result = try await service().translate("Hello", using: configuration(.anthropic))
        XCTAssertEqual(result, "translated")
    }

    func testOllamaKeepsThinkingDisabled() async throws {
        ProviderURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/chat")
            XCTAssertEqual(try self.body(request)["think"] as? Bool, false)
            return (200, #"{"message":{"content":"translated"}}"#)
        }
        let result = try await service().translate("Hello", using: configuration(.ollama, baseURL: "http://localhost:11434"))
        XCTAssertEqual(result, "translated")
    }

    func testNullContentRetriesOnlyOnceWithoutDelimiters() async throws {
        var requests = 0
        ProviderURLProtocol.handler = { request in
            requests += 1
            let messages = try XCTUnwrap(self.body(request)["messages"] as? [[String: String]])
            if requests == 1 {
                XCTAssertTrue(messages[1]["content"]!.contains("<source>"))
                return (200, #"{"choices":[{"message":{"content":null},"finish_reason":"content_filter"}]}"#)
            }
            XCTAssertEqual(messages[1]["content"], "Hello")
            return (200, #"{"choices":[{"message":{"content":"translated"}}]}"#)
        }
        let result = try await service().translate("Hello", using: configuration(.openAICompatible))
        XCTAssertEqual(result, "translated")
        XCTAssertEqual(requests, 2)
    }

    func testTruncatedTranslationDoesNotSilentlySucceed() async throws {
        ProviderURLProtocol.handler = { _ in
            (200, #"{"content":[{"type":"text","text":"partial"}],"stop_reason":"max_tokens"}"#)
        }
        do {
            _ = try await service().translate("Hello", using: configuration(.anthropic))
            XCTFail("Expected a truncation error")
        } catch TranslationServiceError.truncatedTranslation {}
    }

    func testModelDiscoveryFromFullEndpointPreservesQueryAndDeduplicates() async throws {
        ProviderURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/proxy/v1/models")
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "test-version")
            return (200, #"{"data":[{"id":"b"},{"id":"a"},{"id":"b"}]}"#)
        }
        let models = try await service().fetchModels(using: configuration(.openAICompatible, baseURL: "https://example.com/proxy/v1/chat/completions?api-version=test-version"))
        XCTAssertEqual(models, ["a", "b"])
    }

    func testClaudeModelPagination() async throws {
        ProviderURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
            if request.url?.query == nil {
                return (200, #"{"data":[{"id":"first"}],"has_more":true,"last_id":"first"}"#)
            }
            XCTAssertEqual(request.url?.query, "after_id=first")
            return (200, #"{"data":[{"id":"second"}],"has_more":false,"last_id":"second"}"#)
        }
        let models = try await service().fetchModels(using: configuration(.anthropic))
        XCTAssertEqual(models, ["first", "second"])
    }

    func testMissingModelDoesNotSendRequest() async throws {
        ProviderURLProtocol.handler = { _ in
            XCTFail("No request should be sent")
            return (500, "")
        }
        var config = configuration(.openAICompatible)
        config.model = "  "
        do {
            _ = try await service().translate("Hello", using: config)
            XCTFail("Expected missing model error")
        } catch TranslationServiceError.missingModel {}
    }
    func testMissingModelListDoesNotPreventManualTranslation() async throws {
        ProviderURLProtocol.handler = { request in
            if request.url?.path == "/v1/models" {
                return (404, #"{"error":{"message":"Model discovery disabled"}}"#)
            }
            return (200, #"{"choices":[{"message":{"content":"translated"}}]}"#)
        }
        let api = service()
        let config = configuration(.openAICompatible)
        do {
            _ = try await api.fetchModels(using: config)
            XCTFail("Expected discovery failure")
        } catch TranslationServiceError.server(let status, _) {
            XCTAssertEqual(status, 404)
        }
        let result = try await api.translate("Hello", using: config)
        XCTAssertEqual(result, "translated")
    }

    func testOllamaModelListFromFullEndpoint() async throws {
        ProviderURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/tags")
            return (200, #"{"models":[{"name":"qwen-local"}]}"#)
        }
        let models = try await service().fetchModels(using: configuration(.ollama, baseURL: "http://localhost:11434/api/chat"))
        XCTAssertEqual(models, ["qwen-local"])
    }

}
