import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts
import SwiftUI

struct ShortcutRecorderField: View {
    @Binding var shortcut: KeyboardShortcuts.Shortcut?
    @State private var isRecording = false

    var body: some View {
        Button(action: { isRecording.toggle() }) {
            Text(label)
                .frame(minWidth: 100)
                .monospaced()
        }
        .buttonStyle(.bordered)
        .overlay(alignment: .trailing) {
            if shortcut != nil && !isRecording {
                Button {
                    shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }
        }
        .background(KeyCaptureView(isRecording: $isRecording, onCapture: handleCapture))
    }

    private var label: String {
        if isRecording { return "按下快捷键…" }
        return shortcut?.description ?? "点击录制"
    }

    private func handleCapture(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.isEmpty, event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            return
        }
        if modifiers.isEmpty,
           event.specialKey == .delete || event.specialKey == .deleteForward || event.specialKey == .backspace {
            shortcut = nil
            isRecording = false
            return
        }
        guard !modifiers.subtracting(.shift).isEmpty,
              let candidate = KeyboardShortcuts.Shortcut(event: event)
        else {
            NSSound.beep()
            return
        }
        shortcut = candidate
        isRecording = false
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (NSEvent) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.onCapture = onCapture
        isRecording ? nsView.startMonitoring() : nsView.stopMonitoring()
    }

    final class CaptureView: NSView {
        var onCapture: ((NSEvent) -> Void)?
        private var monitor: (any NSObjectProtocol)?

        func startMonitoring() {
            guard monitor == nil else { return }
            KeyboardShortcuts.isEnabled = false
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.onCapture?(event)
                return nil
            } as? (any NSObjectProtocol)
        }

        func stopMonitoring() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
            KeyboardShortcuts.isEnabled = true
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil { stopMonitoring() }
            super.viewWillMove(toWindow: newWindow)
        }
    }
}
