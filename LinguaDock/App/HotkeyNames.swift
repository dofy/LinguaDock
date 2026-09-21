import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openTranslator = Self(
        "openTranslator",
        initial: .init(.t, modifiers: [.command, .shift])
    )

    /// 框选截屏 → OCR → 翻译。
    ///
    /// 默认带满三个修饰键而不是更顺手的 ⌘⇧O：全局热键的优先级高于前台 app 的
    /// 菜单快捷键，⌘⇧O 会在 LinguaDock 运行期间夺走 Xcode 的 Open Quickly；
    /// ⌥⌘O 则和 WordClip 的 OCR 取词撞车（同一组合只有先注册的那个能拿到）。
    static let captureAndTranslate = Self(
        "captureAndTranslate",
        initial: .init(.o, modifiers: [.control, .shift, .command])
    )
}
