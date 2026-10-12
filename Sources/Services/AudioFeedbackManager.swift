import AppKit

public final class AudioFeedbackManager {
    public static let shared = AudioFeedbackManager()

    private let startSound = NSSound(named: "Tink")
    private let stopSound = NSSound(named: "Pop")

    private init() {}

    public func playStartSound() {
        startSound?.play()
    }

    public func playStopSound() {
        stopSound?.play()
    }
}

