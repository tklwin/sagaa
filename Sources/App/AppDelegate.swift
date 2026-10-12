import Cocoa
import SwiftUI
import UserNotifications

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController!
    private var popover: NSPopover!
    private var audioEngine = AudioEngine()
    private var asr: ConformerASR?
    private let state = AppState.shared

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupShortcut()
        setupNotifications()
        loadModelInBackground()

        state.toggleRecordingAction = { [weak self] in
            self?.toggleRecording()
        }
        state.requestAccessibilityAction = { [weak self] in
            self?.requestAccessibility()
        }
        state.openSettingsAction = {
            SettingsWindowController.shared.showSettings()
        }
    }

    private func setupStatusItem() {
        statusController = StatusItemController()

        statusController.onLeftClick = { [weak self] in
            self?.togglePopover()
        }

        statusController.onRightClick = { [weak self] button in
            self?.showContextMenu(from: button)
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let popoverView = SagaaPopoverView(state: state)
        let host = NSHostingController(rootView: popoverView)
        popover.contentViewController = host
    }

    private func togglePopover() {
        guard let button = statusController.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            state.refreshPermissions()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu(from button: NSStatusBarButton?) {
        if popover.isShown {
            popover.performClose(nil)
        }

        let menu = NSMenu()

        // 1. Record / Stop
        let recordTitle = state.isRecording ? "Stop Dictation" : "Start Dictation"
        let recordItem = NSMenuItem(title: recordTitle, action: #selector(menuToggleRecording), keyEquivalent: "r")
        recordItem.target = self
        menu.addItem(recordItem)

        let shortcutItem = NSMenuItem(title: "   Global Shortcut: ⌃⌥S", action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Open Panel
        let openPanelItem = NSMenuItem(title: "Open Panel", action: #selector(menuOpenPanel), keyEquivalent: "o")
        openPanelItem.target = self
        menu.addItem(openPanelItem)

        // 3. Natural Flow toggle
        let naturalFlowItem = NSMenuItem(
            title: "Natural Word Flow: \(state.useNaturalFlow ? "ON" : "OFF")",
            action: #selector(menuToggleNaturalFlow),
            keyEquivalent: ""
        )
        naturalFlowItem.target = self
        menu.addItem(naturalFlowItem)

        // 4. Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Accessibility Check
        let isTrusted = AXIsProcessTrusted()
        let axTitle = isTrusted ? "Accessibility: Granted" : "Accessibility: Request Permission..."
        let axItem = NSMenuItem(title: axTitle, action: isTrusted ? nil : #selector(requestAccessibility), keyEquivalent: "")
        if !isTrusted {
            axItem.target = self
        }
        menu.addItem(axItem)

        menu.addItem(NSMenuItem.separator())

        // 6. Quit
        let quitItem = NSMenuItem(title: "Quit Sagaa", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        let host = statusController.statusItem!
        host.menu = menu
        host.button?.performClick(nil)
        DispatchQueue.main.async {
            host.menu = nil
        }
    }

    @objc private func menuToggleRecording() {
        toggleRecording()
    }

    @objc private func menuOpenPanel() {
        togglePopover()
    }

    @objc private func menuToggleNaturalFlow() {
        state.useNaturalFlow.toggle()
    }

    @objc private func menuOpenSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.state.refreshPermissions()
        }
    }

    private func setupShortcut() {
        GlobalShortcutManager.shared.onKeyDown = { [weak self] in
            guard let self = self else { return }
            if !self.state.isRecording {
                self.startRecording()
            } else {
                self.stopRecordingAndTranscribe()
            }
        }

        GlobalShortcutManager.shared.onKeyUp = { [weak self] duration in
            guard let self = self else { return }
            if self.state.isRecording && self.state.pushToTalk && duration >= 0.4 {
                self.stopRecordingAndTranscribe()
            }
        }

        GlobalShortcutManager.shared.registerDefaultShortcut()
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func loadModelInBackground() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let bundle = Bundle.main
            guard let modelURL = bundle.url(forResource: "BurmeseASR", withExtension: "mlmodelc") ??
                                 bundle.url(forResource: "BurmeseASR", withExtension: "mlpackage"),
                  let vocabURL = bundle.url(forResource: "vocab", withExtension: "json") else {
                print("⚠️ Model resources not found in app bundle")
                return
            }

            do {
                let asrModel = try ConformerASR(modelURL: modelURL, vocabURL: vocabURL)
                self.asr = asrModel
                DispatchQueue.main.async {
                    self.state.isModelReady = true
                    print("✅ Sagaa End-to-End CoreML Engine Ready!")
                }
            } catch {
                print("❌ Failed to load CoreML model: \(error)")
            }
        }
    }

    public func toggleRecording() {
        if !state.isRecording {
            startRecording()
        } else {
            stopRecordingAndTranscribe()
        }
    }

    private func startRecording() {
        guard state.isModelReady else {
            showNotification(title: "Sagaa", message: "Model is warming up...")
            return
        }

        // Record the application that currently has focus BEFORE taking action
        TextInjector.shared.recordTargetApplication()

        do {
            try audioEngine.startRecording { [weak self] level in
                DispatchQueue.main.async {
                    self?.state.audioLevel = level
                }
            }
            state.isRecording = true
            statusController.setRecordingState()
            if state.soundFeedback {
                AudioFeedbackManager.shared.playStartSound()
            }
            if state.showFloatingHUD {
                SagaaHUDController.shared.show()
            }
        } catch {
            showNotification(title: "Sagaa Error", message: "Microphone access failed: \(error.localizedDescription)")
            SagaaHUDController.shared.hide()
        }
    }

    private func stopRecordingAndTranscribe() {
        state.isRecording = false
        state.isTranscribing = true
        statusController.setTranscribingState()

        if state.soundFeedback {
            AudioFeedbackManager.shared.playStopSound()
        }

        // Close popover if open so the target app can immediately regain frontmost focus
        if popover.isShown {
            popover.performClose(nil)
        }

        let audioSamples = audioEngine.stopRecording()
        state.audioLevel = 0.0

        guard audioSamples.count >= 8000 else {
            state.isTranscribing = false
            statusController.setIdleState()
            SagaaHUDController.shared.hide(afterDelay: 0.15)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let asr = self.asr else {
                DispatchQueue.main.async {
                    self?.state.isTranscribing = false
                    self?.statusController.setIdleState()
                    SagaaHUDController.shared.hide(afterDelay: 0.15)
                }
                return
            }

            do {
                let t0 = CFAbsoluteTimeGetCurrent()
                let rawText = try asr.transcribe(audio: audioSamples)
                let latency = (CFAbsoluteTimeGetCurrent() - t0) * 1000

                // Apply Burmese post-processing
                let finalText = self.state.useNaturalFlow ?
                    BurmesePostProcessor.shared.format(syllables: rawText) : rawText

                DispatchQueue.main.async {
                    self.state.isTranscribing = false
                    self.statusController.setIdleState()
                    self.state.lastTranscription = finalText
                    self.state.lastLatencyMs = latency

                    if !finalText.isEmpty {
                        // Add to persistent history
                        self.state.addRecord(text: finalText, latencyMs: latency)

                        if self.state.autoPaste {
                            TextInjector.shared.inject(text: finalText, pasteDelayMs: self.state.pasteDelayMs)
                        } else {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(finalText, forType: .string)
                        }
                        self.showNotification(title: "✅ Sagaa (\(String(format: "%.0f", latency))ms)", message: finalText)
                        SagaaHUDController.shared.hide(afterDelay: 0.85)
                    } else {
                        SagaaHUDController.shared.hide(afterDelay: 0.2)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.state.isTranscribing = false
                    self.statusController.setIdleState()
                    self.showNotification(title: "Sagaa Error", message: error.localizedDescription)
                    SagaaHUDController.shared.hide(afterDelay: 0.2)
                }
            }
        }
    }


    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
