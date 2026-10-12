import Foundation
import AppKit
import AVFoundation
import Combine

public struct DictationRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let text: String
    public let latencyMs: Double
    public let wordCount: Int

    public init(id: UUID = UUID(), timestamp: Date = Date(), text: String, latencyMs: Double) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.latencyMs = latencyMs
        self.wordCount = text.split(separator: " ").count
    }
}

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case dictation = "Dictation"
    case shortcuts = "Shortcuts"
    case history = "History"
    case permissions = "Permissions"
    case about = "About"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .dictation: return "mic"
        case .shortcuts: return "command"
        case .history: return "clock"
        case .permissions: return "lock.shield"
        case .about: return "info.circle"
        }
    }
}

public final class AppState: ObservableObject {
    public static let shared = AppState()

    // Runtime state
    @Published public var isRecording = false
    @Published public var isTranscribing = false
    @Published public var isModelReady = false
    @Published public var audioLevel: Float = 0.0
    @Published public var lastTranscription = ""
    @Published public var lastLatencyMs: Double? = nil
    @Published public var isAccessibilityGranted = false
    @Published public var isMicrophoneGranted = false
    @Published public var copiedFeedback = false
    @Published public var selectedSettingsTab: SettingsTab = .general
    @Published public var copiedHistoryRecordId: UUID? = nil

    // Persistent settings
    @Published public var showFloatingHUD: Bool {
        didSet { UserDefaults.standard.set(showFloatingHUD, forKey: "showFloatingHUD") }
    }
    @Published public var pushToTalk: Bool {
        didSet { UserDefaults.standard.set(pushToTalk, forKey: "pushToTalk") }
    }
    @Published public var useNaturalFlow: Bool {
        didSet { UserDefaults.standard.set(useNaturalFlow, forKey: "useNaturalFlow") }
    }
    @Published public var autoPaste: Bool {
        didSet { UserDefaults.standard.set(autoPaste, forKey: "autoPaste") }
    }
    @Published public var pasteDelayMs: Int {
        didSet { UserDefaults.standard.set(pasteDelayMs, forKey: "pasteDelayMs") }
    }
    @Published public var soundFeedback: Bool {
        didSet { UserDefaults.standard.set(soundFeedback, forKey: "soundFeedback") }
    }
    @Published public var launchAtLogin: Bool {
        didSet { LaunchAtLoginManager.shared.isEnabled = launchAtLogin }
    }
    @Published public var history: [DictationRecord] = [] {
        didSet { saveHistory() }
    }

    // Callbacks
    public var toggleRecordingAction: (() -> Void)?
    public var requestAccessibilityAction: (() -> Void)?
    public var openSettingsAction: (() -> Void)?

    private init() {
        let defaults = UserDefaults.standard
        self.showFloatingHUD = defaults.object(forKey: "showFloatingHUD") == nil ? true : defaults.bool(forKey: "showFloatingHUD")
        self.pushToTalk = defaults.object(forKey: "pushToTalk") == nil ? true : defaults.bool(forKey: "pushToTalk")
        self.useNaturalFlow = defaults.object(forKey: "useNaturalFlow") == nil ? true : defaults.bool(forKey: "useNaturalFlow")
        self.autoPaste = defaults.object(forKey: "autoPaste") == nil ? true : defaults.bool(forKey: "autoPaste")
        self.pasteDelayMs = defaults.object(forKey: "pasteDelayMs") == nil ? 80 : defaults.integer(forKey: "pasteDelayMs")
        self.soundFeedback = defaults.object(forKey: "soundFeedback") == nil ? true : defaults.bool(forKey: "soundFeedback")
        self.launchAtLogin = LaunchAtLoginManager.shared.isEnabled

        self.isAccessibilityGranted = AXIsProcessTrusted()
        self.isMicrophoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

        loadHistory()
    }

    public func refreshPermissions() {
        self.isAccessibilityGranted = AXIsProcessTrusted()
        self.isMicrophoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    public func addRecord(text: String, latencyMs: Double) {
        guard !text.isEmpty else { return }
        let record = DictationRecord(text: text, latencyMs: latencyMs)
        history.insert(record, at: 0)
        if history.count > 30 {
            history.removeLast()
        }
    }

    public func clearHistory() {
        history.removeAll()
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "dictation_history")
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "dictation_history"),
           let decoded = try? JSONDecoder().decode([DictationRecord].self, from: data) {
            self.history = decoded
        }
    }
}
