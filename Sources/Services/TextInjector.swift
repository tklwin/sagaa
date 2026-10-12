import Foundation
import AppKit
import Carbon.HIToolbox

public final class TextInjector {
    public static let shared = TextInjector()

    private var targetApplication: NSRunningApplication?
    private var lastActiveExternalApp: NSRunningApplication?

    private init() {
        // Track the user's active applications in the background so we always know where to paste
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let ownID = Bundle.main.bundleIdentifier
            if app.bundleIdentifier != ownID && app.activationPolicy == .regular && !app.isTerminated {
                self?.lastActiveExternalApp = app
            }
        }
    }

    /// Records the application that currently has user focus before any Sagaa UI takes focus
    public func recordTargetApplication() {
        let ownID = Bundle.main.bundleIdentifier
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != ownID,
           frontApp.activationPolicy == .regular,
           !frontApp.isTerminated {
            self.targetApplication = frontApp
        } else if let fallback = lastActiveExternalApp, !fallback.isTerminated {
            self.targetApplication = fallback
        }
    }

    /// Insert text at current cursor position in the target application
    public func inject(text: String, pasteDelayMs: Int = 100, completion: ((Bool) -> Void)? = nil) {
        guard !text.isEmpty else {
            completion?(false)
            return
        }

        // 1. Always copy text to clipboard as guaranteed fallback
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Determine target application to paste into
        let appToActivate = (targetApplication != nil && !targetApplication!.isTerminated) ? targetApplication : lastActiveExternalApp

        // 2. Verify Accessibility Permission
        guard AXIsProcessTrusted() else {
            print("⚠️ Accessibility permission not granted. Attempting AppleScript fallback...")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            
            // Try AppleScript fallback even if AX check is false
            if let target = appToActivate, !target.isTerminated {
                target.activate(options: [.activateIgnoringOtherApps])
            }
            self.fallbackAppleScriptPaste(completion: completion)
            return
        }

        // 3. Re-activate the target application where the user was typing
        if let target = appToActivate, !target.isTerminated {
            target.activate(options: [.activateIgnoringOtherApps])
        }

        // 4. Wait for physical modifier keys to release before posting Cmd+V
        postPasteWhenModifiersReleased(attempt: 0, delayMs: pasteDelayMs) { success in
            if !success {
                self.fallbackAppleScriptPaste(completion: completion)
            } else {
                completion?(true)
            }
        }
    }

    private func postPasteWhenModifiersReleased(attempt: Int, delayMs: Int, completion: @escaping (Bool) -> Void) {
        let held = CGEventSource.flagsState(.combinedSessionState)
            .intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])

        // If modifiers are released or timeout reached (1.2 seconds)
        if held.isEmpty || attempt >= 80 {
            let delaySeconds = Double(max(delayMs, 80)) / 1000.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
                self.postPasteKeystrokes(completion: completion)
            }
            return
        }

        // Check again after 15ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) {
            self.postPasteWhenModifiersReleased(attempt: attempt + 1, delayMs: delayMs, completion: completion)
        }
    }


    private func postPasteKeystrokes(completion: @escaping (Bool) -> Void) {
        let kVK_ANSI_V: CGKeyCode = 9 // ANSI 'v'

        guard let source = CGEventSource(stateID: .hidSystemState),
              let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_V, keyDown: true),
              let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_V, keyDown: false) else {
            completion(false)
            return
        }

        cmdDown.flags = .maskCommand
        cmdUp.flags = .maskCommand

        cmdDown.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            cmdUp.post(tap: .cghidEventTap)
            completion(true)
        }
    }

    private func fallbackAppleScriptPaste(completion: ((Bool) -> Void)?) {
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptSource = "tell application \"System Events\" to keystroke \"v\" using command down"
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                DispatchQueue.main.async {
                    completion?(error == nil)
                }
            } else {
                DispatchQueue.main.async {
                    completion?(false)
                }
            }
        }
    }
}
