import Cocoa
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var audioEngine = AudioEngine()
    private var asr: ConformerASR?
    private var melExtractor: MelSpectrogramExtractor?
    private var isRecording = false
    private var isModelReady = false
    private var useNaturalFlow = true

    // Native SF Symbols (Template Images)
    private var idleIcon: NSImage?
    private var recordingIcon: NSImage?
    private var naturalFlowMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupIcons()
        setupStatusItem()
        loadModelInBackground()
    }

    private func setupIcons() {
        // Native Apple SF Symbol monochrome template images
        if let idle = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Sagaa") {
            idle.isTemplate = true // Automatically adapts to Dark/Light mode
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
            button.imagePosition = .imageOnly
            button.action = #selector(toggleRecording)
            button.target = self
        }

        let menu = NSMenu()
        let recordItem = NSMenuItem(title: "Record / Stop", action: #selector(toggleRecording), keyEquivalent: "r")
        menu.addItem(recordItem)

        menu.addItem(NSMenuItem.separator())

        naturalFlowMenuItem = NSMenuItem(title: "သဘာဝ စာလုံးပေါင်း (Natural Flow): ON", action: #selector(toggleNaturalFlow), keyEquivalent: "")
        menu.addItem(naturalFlowMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Sagaa", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleNaturalFlow() {
        useNaturalFlow.toggle()
        naturalFlowMenuItem.title = "သဘာဝ စာလုံးပေါင်း (Natural Flow): \(useNaturalFlow ? "ON" : "OFF")"
    }

    private func loadModelInBackground() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let bundle = Bundle.main
            guard let modelURL = bundle.url(forResource: "BurmeseASR", withExtension: "mlmodelc") ??
                                 bundle.url(forResource: "BurmeseASR", withExtension: "mlpackage"),
                  let cmvnURL = bundle.url(forResource: "cmvn", withExtension: "json"),
                  let vocabURL = bundle.url(forResource: "vocab", withExtension: "json"),
                  let melURL = bundle.url(forResource: "mel_filters", withExtension: "json") else {
                print("⚠️ Model resources not found in app bundle")
                return
            }

            do {
                let asrModel = try ConformerASR(modelURL: modelURL, cmvnURL: cmvnURL, vocabURL: vocabURL)
                let extractor = try MelSpectrogramExtractor(melFiltersURL: melURL,
                                                            cmvnMean: asrModel.cmvnMean,
                                                            cmvnStd: asrModel.cmvnStd)
                self.asr = asrModel
                self.melExtractor = extractor
                self.isModelReady = true
                print("✅ Sagaa CoreML Engine Ready!")
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
            statusItem.button?.image = recordingIcon
        } catch {
            showNotification(title: "Sagaa Error", message: "Microphone access failed: \(error.localizedDescription)")
        }
    }

    private func stopRecordingAndTranscribe() {
        isRecording = false
        statusItem.button?.image = idleIcon

        let audioSamples = audioEngine.stopRecording()
        guard audioSamples.count >= 8000 else {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let asr = self.asr,
                  let melExtractor = self.melExtractor else { return }

            do {
                let t0 = CFAbsoluteTimeGetCurrent()
                let mel = try melExtractor.extract(audio: audioSamples)
                let rawText = try asr.transcribe(mel: mel)
                let latency = (CFAbsoluteTimeGetCurrent() - t0) * 1000

                // Apply Burmese post-processing
                let finalText = self.useNaturalFlow ?
                    BurmesePostProcessor.shared.format(syllables: rawText) : rawText

                DispatchQueue.main.async {
                    if !finalText.isEmpty {
                        TextInjector.shared.inject(text: finalText)
                        self.showNotification(title: "✅ Sagaa (\(String(format: "%.0f", latency))ms)", message: finalText)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showNotification(title: "Sagaa Error", message: error.localizedDescription)
                }
            }
        }
    }

    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        NSUserNotificationCenter.default.deliver(notification)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
