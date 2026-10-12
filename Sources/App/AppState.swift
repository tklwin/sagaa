import Foundation
import AppKit
import Combine

public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var isRecording = false
    @Published public var isTranscribing = false
    @Published public var isModelReady = false
    @Published public var useNaturalFlow = true
    @Published public var autoPaste = true
    @Published public var launchAtLogin = false
    @Published public var audioLevel: Float = 0.0
    @Published public var lastTranscription = ""
    @Published public var lastLatencyMs: Double? = nil
    @Published public var isAccessibilityGranted = false
    @Published public var copiedFeedback = false

    public var toggleRecordingAction: (() -> Void)?
    public var requestAccessibilityAction: (() -> Void)?

    private init() {
        self.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
        self.isAccessibilityGranted = AXIsProcessTrusted()
    }

    public func refreshAccessibility() {
        self.isAccessibilityGranted = AXIsProcessTrusted()
    }
}
