import Cocoa
import SwiftUI
import UserNotifications

@main
final class SagaaApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var audioEngine = AudioEngine()
    private var asr: ConformerASR?
    private var isRecording = false
    private var isTranscribing = false
    private var isModelReady = false
    private var useNaturalFlow = true

    // Native SF Symbols (Template Images)
    private var idleIcon: NSImage?
    private var recordingIcon: NSImage?
    private var naturalFlowMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupIcons()
        setupStatusItem()
        setupGlobalShortcut()
        requestNotificationPermission()
        loadModelInBackground()
    }

    private func setupIcons() {
        if let idle = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Sagaa") {
            idle.isTemplate = true
            self.idleIcon = idle
        }

        if let rec = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording") {
            rec.isTemplate = true
            self.recordingIcon = rec
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = idleIcon
            button.imagePosition = .imageLeading
            button.title = " Sagaa"
            button.toolTip = "Sagaa - မြန်မာ အသံထွက် စာပြောင်းစနစ်\nဖြတ်လမ်းခလုတ်: Control+Option+S"
        }
        rebuildMenu()
    }

    private func setupGlobalShortcut() {
        // Global Hotkey: Control + Option + S (keyCode 1 is 's')
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.control, .option]) && event.keyCode == 1 {
                DispatchQueue.main.async {
                    self?.toggleRecording()
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // 1. Record / Stop Item
        let recordTitle = isRecording ? "■ ရပ်တန့်၍ စာထည့်မည် (Stop Dictation)" : "● စတင် အသံဖမ်းမည် (Start Dictation)"
        let recordItem = NSMenuItem(title: recordTitle, action: #selector(toggleRecording), keyEquivalent: "r")
        recordItem.target = self
        menu.addItem(recordItem)

        let shortcutItem = NSMenuItem(title: "   ဖြတ်လမ်းခလုတ် (Shortcut): ⌃⌥S", action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Status display
        let statusText: String
        if isRecording {
            statusText = "အခြေအနေ: အသံဖမ်းနေသည်... (Recording)"
        } else if isTranscribing {
            statusText = "အခြေအနေ: စာပြောင်းနေသည်... (Transcribing)"
        } else if isModelReady {
            statusText = "အခြေအနေ: အသင့်ဖြစ်ပါပြီ (Ready)"
        } else {
            statusText = "အခြေအနေ: Model ဖွင့်နေသည်... (Loading)"
        }
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Natural Flow toggle
        naturalFlowMenuItem = NSMenuItem(
            title: "သဘာဝ စာလုံးပေါင်း (Natural Flow): \(useNaturalFlow ? "ဖွင့်ထားသည် (ON)" : "ပိတ်ထားသည် (OFF)")",
            action: #selector(toggleNaturalFlow),
            keyEquivalent: ""
        )
        naturalFlowMenuItem.target = self
        menu.addItem(naturalFlowMenuItem)

        // 4. Accessibility Check
        let isTrusted = AXIsProcessTrusted()
        let axTitle = isTrusted ? "✓ စာရိုက်သွင်းခွင့် (Accessibility): ခွင့်ပြုပြီး" : "⚠️ စာရိုက်သွင်းခွင့် (Accessibility) တောင်းခံမည်"
        let axItem = NSMenuItem(title: axTitle, action: isTrusted ? nil : #selector(requestAccessibility), keyEquivalent: "")
        if !isTrusted {
            axItem.target = self
        }
        menu.addItem(axItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Quit
        let quitItem = NSMenuItem(title: "Quit Sagaa", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @objc private func toggleNaturalFlow() {
        useNaturalFlow.toggle()
        rebuildMenu()
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
                self.isModelReady = true
                print("✅ Sagaa End-to-End CoreML Engine Ready!")
                DispatchQueue.main.async {
                    self.rebuildMenu()
                }
            } catch {
                print("❌ Failed to load CoreML model: \(error)")
            }
        }
    }

    @objc private func toggleRecording() {
        if !isRecording {
            startRecording()
        } else {
            stopRecordingAndTranscribe()
        }
    }

    private func startRecording() {
        guard isModelReady else {
            showNotification(title: "Sagaa", message: "Model is warming up...")
            return
        }

        do {
            try audioEngine.startRecording()
            isRecording = true
            DispatchQueue.main.async {
                self.statusItem.button?.image = self.recordingIcon
                self.statusItem.button?.title = " အသံဖမ်းနေသည်..."
                self.rebuildMenu()
            }
        } catch {
            showNotification(title: "Sagaa Error", message: "Microphone access failed: \(error.localizedDescription)")
        }
    }

    private func stopRecordingAndTranscribe() {
        isRecording = false
        isTranscribing = true
        statusItem.button?.image = idleIcon
        statusItem.button?.title = " စာပြောင်းနေသည်..."
        rebuildMenu()

        let audioSamples = audioEngine.stopRecording()
        guard audioSamples.count >= 8000 else {
            isTranscribing = false
            statusItem.button?.title = " Sagaa"
            rebuildMenu()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let asr = self.asr else {
                DispatchQueue.main.async {
                    self?.isTranscribing = false
                    self?.statusItem.button?.title = " Sagaa"
                    self?.rebuildMenu()
                }
                return
            }

            do {
                let t0 = CFAbsoluteTimeGetCurrent()
                let rawText = try asr.transcribe(audio: audioSamples)
                let latency = (CFAbsoluteTimeGetCurrent() - t0) * 1000

                // Apply Burmese post-processing
                let finalText = self.useNaturalFlow ?
                    BurmesePostProcessor.shared.format(syllables: rawText) : rawText

                DispatchQueue.main.async {
                    self.isTranscribing = false
                    self.statusItem.button?.title = " Sagaa"
                    self.rebuildMenu()

                    if !finalText.isEmpty {
                        TextInjector.shared.inject(text: finalText)
                        self.showNotification(title: "✅ Sagaa (\(String(format: "%.0f", latency))ms)", message: finalText)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    self.statusItem.button?.title = " Sagaa"
                    self.rebuildMenu()
                    self.showNotification(title: "Sagaa Error", message: error.localizedDescription)
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
