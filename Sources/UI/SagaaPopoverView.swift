import SwiftUI
import AppKit

public struct SagaaPopoverView: View {
    @ObservedObject public var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 14) {
            headerSection
            heroDictationSection
            recentTranscriptionSection
            quickTogglesSection
            footerSection
        }
        .padding(18)
        .frame(width: 350)
    }

    // MARK: - 1. Header
    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(SagaaTheme.primaryAccent)
                .frame(width: 30, height: 30)
                .background(SagaaTheme.primaryAccent.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Sagaa")
                    .font(.system(size: 15, weight: .bold))
                Text("Burmese Speech-to-Text")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(state.isModelReady ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(state.isModelReady ? "ANE Active" : "Warming up")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(12)

            // Settings Gear Button
            Button(action: {
                state.openSettingsAction?()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open Settings (⌘,)")
        }
    }

    // MARK: - 2. Hero Dictation Section
    private var heroDictationSection: some View {
        VStack(spacing: 10) {
            Button(action: {
                state.toggleRecordingAction?()
            }) {
                ZStack {
                    Circle()
                        .fill(state.isRecording ? SagaaTheme.recordingRed : SagaaTheme.primaryAccent)
                        .frame(width: 64, height: 64)
                        .shadow(color: (state.isRecording ? SagaaTheme.recordingRed : SagaaTheme.primaryAccent).opacity(0.35),
                                radius: state.isRecording ? 10 : 4, x: 0, y: 2)

                    if state.isTranscribing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.1)
                    } else if state.isRecording {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!state.isModelReady || state.isTranscribing)

            VStack(spacing: 3) {
                if state.isTranscribing {
                    Text("Transcribing speech...")
                        .font(.system(size: 13, weight: .semibold))
                } else if state.isRecording {
                    Text("Recording speech...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SagaaTheme.recordingRed)
                } else {
                    Text("Click to Dictate")
                        .font(.system(size: 13, weight: .semibold))
                }

                AudioVisualizerView(level: state.audioLevel, isRecording: state.isRecording)

                Text("Shortcut: ⌃⌥S (Control + Option + S)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - 3. Recent Transcription
    private var recentTranscriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Latest Output")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if let latency = state.lastLatencyMs {
                    Text("\(String(format: "%.0f", latency)) ms")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            if !state.lastTranscription.isEmpty {
                Text(state.lastTranscription)
                    .font(.system(size: 13.5))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)

                HStack {
                    Spacer()
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: state.copiedFeedback ? "checkmark" : "doc.on.doc")
                            Text(state.copiedFeedback ? "Copied" : "Copy")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(state.copiedFeedback ? .green : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                Text("Press ⌃⌥S or click above to dictate anywhere.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding(12)
        .cardStyle()
    }

    // MARK: - 4. Quick Toggles
    private var quickTogglesSection: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $state.useNaturalFlow) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Natural Word Flow")
                        .font(.system(size: 12, weight: .medium))
                    Text("Rejoin syllables into natural Burmese words")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: SagaaTheme.primaryAccent))

            Divider().opacity(0.6)

            Toggle(isOn: $state.autoPaste) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Auto-Paste into Active App")
                        .font(.system(size: 12, weight: .medium))
                    Text("Type directly at cursor location in target app")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: SagaaTheme.primaryAccent))
        }
        .padding(12)
        .cardStyle()
    }

    // MARK: - 5. Footer
    private var footerSection: some View {
        HStack {
            if !state.isAccessibilityGranted {
                Button(action: {
                    state.requestAccessibilityAction?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Accessibility Required")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Access Granted")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Settings...") {
                state.openSettingsAction?()
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .buttonStyle(PlainButtonStyle())

            Text("•")
                .foregroundColor(.secondary.opacity(0.5))

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func copyToClipboard() {
        guard !state.lastTranscription.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(state.lastTranscription, forType: .string)
        withAnimation {
            state.copiedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                self.state.copiedFeedback = false
            }
        }
    }
}
