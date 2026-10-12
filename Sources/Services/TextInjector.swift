import Foundation
import AppKit

public final class TextInjector {
    public static let shared = TextInjector()
    private init() {}

    /// Insert text at current cursor position
    public func inject(text: String) {
        guard !text.isEmpty else { return }

        // 1. Save to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 2. Check accessibility permissions
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            print("⚠️ Accessibility permission not granted yet. Text is copied to clipboard.")
            return
        }

        // 3. Small delay to ensure focus is steady before Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePasteKeystroke()
        }
    }

    private func simulatePasteKeystroke() {
        let kVK_ANSI_V: CGKeyCode = 9

        let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: kVK_ANSI_V, keyDown: true)
        cmdDown?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)

        usleep(40_000) // 40ms

        let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: kVK_ANSI_V, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cghidEventTap)
    }
}
