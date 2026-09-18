import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
enum SelectedTextReader {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccessibilityPermission() {
        // Use the documented key value directly. Importing the legacy global
        // kAXTrustedCheckOptionPrompt trips Swift 6's shared-state checker.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func readSelectedText() async -> String? {
        if let selected = readUsingAccessibility(), !selected.isEmpty {
            return selected
        }
        return await readUsingCopyShortcut()
    }

    private static func readUsingAccessibility() -> String? {
        guard isTrusted else { return nil }
        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue
        else { return nil }

        let focused = unsafeDowncast(focusedValue, to: AXUIElement.self)
        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        ) == .success
        else { return nil }
        return (selectedValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readUsingCopyShortcut() async -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let initialChangeCount = pasteboard.changeCount

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else { return nil }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        try? await Task.sleep(for: .milliseconds(220))
        let copied = pasteboard.changeCount != initialChangeCount
            ? pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        snapshot.restore(to: pasteboard)
        return copied?.isEmpty == false ? copied : nil
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems = items.map { values in
            let item = NSPasteboardItem()
            for (type, data) in values {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
