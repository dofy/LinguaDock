import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
enum SelectedTextReader {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccessibilityPermission() {
        // Ask macOS to register the running app with TCC first. Opening the
        // settings pane alone does not add a missing app to the list.
        // This is the documented value of kAXTrustedCheckOptionPrompt. Referencing
        // that legacy global directly fails Swift 6 strict concurrency checks.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard !AXIsProcessTrustedWithOptions(options) else { return }

        // macOS only presents the alert once. On later attempts, take the user
        // directly to the Accessibility pane instead of leaving Settings on
        // whichever page happened to be open.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !AXIsProcessTrusted(),
                  let url = URL(
                      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                  )
            else { return }
            NSWorkspace.shared.open(url)
        }
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
        // The hotkey callback fires when T is released, while Command and Shift
        // may still be held. Wait for them to clear before synthesizing Command-C.
        await waitForShortcutModifiersToBeReleased()
        guard !Task.isCancelled else { return nil }

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

        // Copying can be asynchronous in browsers and Electron apps. Observe the
        // pasteboard instead of relying on one fixed delay.
        for _ in 0..<30 where pasteboard.changeCount == initialChangeCount {
            try? await Task.sleep(for: .milliseconds(25))
            if Task.isCancelled { break }
        }
        let copied = pasteboard.changeCount != initialChangeCount
            ? pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        snapshot.restore(to: pasteboard)
        return copied?.isEmpty == false ? copied : nil
    }

    private static func waitForShortcutModifiersToBeReleased() async {
        let modifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        for _ in 0..<40 {
            if NSEvent.modifierFlags.intersection(modifiers).isEmpty { return }
            try? await Task.sleep(for: .milliseconds(25))
            if Task.isCancelled { return }
        }
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
