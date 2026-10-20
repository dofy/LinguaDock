import XCTest
@testable import LinguaDock

final class TranslationDirectionTests: XCTestCase {
    private func target(_ source: TargetLanguage?, smart: Bool = true,
                        fixed: TargetLanguage = .simplifiedChinese,
                        primary: TargetLanguage = .simplifiedChinese,
                        fallback: TargetLanguage = .english) -> TargetLanguage {
        TranslationDirection.resolve(source: source, smart: smart, fixed: fixed,
                                     primary: primary, fallback: fallback).target
    }

    func testSmartModeRoutesBothChineseScriptsToEnglish() {
        XCTAssertEqual(target(.simplifiedChinese), .english)
        XCTAssertEqual(target(.traditionalChinese), .english)
        XCTAssertEqual(target(.english), .simplifiedChinese)
        XCTAssertEqual(target(.japanese), .simplifiedChinese)
    }

    func testUncertainInputKeepsPrimaryAndCustomLanguagePairWorks() {
        XCTAssertEqual(target(nil), .simplifiedChinese)
        XCTAssertEqual(target(.japanese, primary: .japanese, fallback: .korean), .korean)
        XCTAssertEqual(target(.english, primary: .japanese, fallback: .korean), .japanese)
    }

    func testFixedTargetAllowsChineseScriptConversionAndSameLanguageInput() {
        XCTAssertEqual(target(.traditionalChinese, smart: false), .simplifiedChinese)
        XCTAssertEqual(target(.simplifiedChinese, smart: false), .simplifiedChinese)
        XCTAssertEqual(target(.english, smart: false, fixed: .japanese), .japanese)
    }

    func testDetectsProseAndMixedChineseWithoutBeingDistractedByCode() {
        XCTAssertTrue(TranslationDirection.detectSource(in: "你好，世界。今天我们讨论一下翻译设置。")?.isSameLanguage(as: .simplifiedChinese) == true)
        XCTAssertTrue(TranslationDirection.detectSource(in: "請先確認付款是否成功，再決定是否重新扣款。")?.isSameLanguage(as: .simplifiedChinese) == true)
        XCTAssertTrue(TranslationDirection.detectSource(in: "这个 API 请求失败后不要自动 retry，请先检查 payment 状态。")?.isSameLanguage(as: .simplifiedChinese) == true)
        XCTAssertEqual(TranslationDirection.detectSource(in: "Please confirm whether the payment has succeeded before trying again."), .english)
        XCTAssertEqual(TranslationDirection.detectSource(in: "田中さんに確認していただけますか。"), .japanese)
        let text = "请先确认付款是否成功，再决定是否重新扣款。\n```sh\n" + String(repeating: "echo Check the payment status before retrying\n", count: 30) + "```"
        XCTAssertTrue(TranslationDirection.detectSource(in: text)?.isSameLanguage(as: .simplifiedChinese) == true)
    }

    func testAmbiguousAndCodeOnlyInputDoesNotTriggerDirectionSwitch() {
        for text in ["", "12345", "API", "OK", "```sh\ncurl https://example.com\n```", "https://example.com/payment/status"] {
            XCTAssertNil(TranslationDirection.detectSource(in: text), text)
        }
    }
}

@MainActor
final class SmartTranslationSettingsTests: XCTestCase {
    func testDefaultsPersistenceAndInvalidPairs() throws {
        let name = "LinguaDockTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let keys = ModelKeyStore(load: { _ in "" }, save: { _, _ in }, migrate: {})
        let state = AppState(defaults: defaults, keyStore: keys)
        XCTAssertTrue(state.smartTranslationEnabled)
        state.sourceText = "请先确认付款是否成功，再决定是否重新扣款。"
        XCTAssertEqual(state.translationDirection.target, .english)
        state.targetLanguage = .simplifiedChinese
        state.smartTranslationEnabled = false
        XCTAssertEqual(state.translationDirection.target, .simplifiedChinese)
        state.primaryTranslationLanguage = .japanese
        state.fallbackTranslationLanguage = .korean
        let reopened = AppState(defaults: defaults, keyStore: keys)
        XCTAssertFalse(reopened.smartTranslationEnabled)
        XCTAssertEqual(reopened.primaryTranslationLanguage, .japanese)
        XCTAssertEqual(reopened.fallbackTranslationLanguage, .korean)
        reopened.primaryTranslationLanguage = .korean
        XCTAssertEqual(reopened.fallbackTranslationLanguage, .english)
        reopened.primaryTranslationLanguage = .traditionalChinese
        reopened.fallbackTranslationLanguage = .simplifiedChinese
        XCTAssertEqual(reopened.fallbackTranslationLanguage, .english)
    }
}
