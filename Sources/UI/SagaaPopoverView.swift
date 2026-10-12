import SwiftUI
import AppKit

public struct SagaaPopoverView: View {
    @ObservedObject public var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 16) {
            headerSection
            heroDictationSection
            recentTranscriptionSection
            settingsSection
            footerSection
        }
        .padding(18)
        .frame(width: 340)
    }

    // MARK: - 1. Header
    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(SagaaTheme.primaryAccent)
                .frame(width: 32, height: 32)
                .background(SagaaTheme.primaryAccent.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Sagaa")
                        .font(.system(size: 15, weight: .bold))
                    Text("(စကား)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
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
                Text(state.isModelReady ? "ANE Active" : "Loading")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(12)
        }
    }

    // MARK: - 2. Hero Dictation Section
    private var heroDictationSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                state.toggleRecordingAction?()
            }) {
                ZStack {
                    Circle()
                        .fill(state.isRecording ? SagaaTheme.recordingRed : SagaaTheme.primaryAccent)
                        .frame(width: 68, height: 68)
                        .shadow(color: (state.isRecording ? SagaaTheme.recordingRed : SagaaTheme.primaryAccent).opacity(0.35),
                                radius: state.isRecording ? 10 : 4, x: 0, y: 2)

                    if state.isTranscribing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    } else if state.isRecording {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!state.isModelReady || state.isTranscribing)

            VStack(spacing: 4) {
                if state.isTranscribing {
                    Text("စာပြောင်းနေပါသည်...")
                        .font(.system(size: 13, weight: .semibold))
                } else if state.isRecording {
                    Text("အသံဖမ်းယူနေပါသည် (Recording...)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SagaaTheme.recordingRed)
                } else {
                    Text("စတင် အသံဖမ်းမည် (Click to Dictate)")
                        .font(.system(size: 13, weight: .semibold))
                }

                AudioVisualizerView(level: state.audioLevel, isRecording: state.isRecording)

                Text("ဖြတ်လမ်းခလုတ်: ⌃⌥S (Control + Option + S)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - 3. Recent Transcription
    private var recentTranscriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("နောက်ဆုံး ရလဒ် (Latest Output)")
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
                    .font(.system(size: 14))
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
                            Text(state.copiedFeedback ? "ကူးယူပြီးပါပြီ" : "Copy")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(state.copiedFeedback ? .green : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                Text("စကားပြောပြီးသည်နှင့် စာသားများ ဤနေရာတွင် ပေါ်လာပါမည်။")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding(12)
        .cardStyle()
    }

    // MARK: - 4. Settings Card Group
    private var settingsSection: some View {
        VStack(spacing: 10) {
            Toggle(isOn: $state.useNaturalFlow) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("သဘာဝ စာလုံးပေါင်း (Natural Flow)")
                        .font(.system(size: 12, weight: .medium))
                    Text("စကားလုံးများ အလိုက် သဘာဝကျစွာ ပေါင်းစပ်မည်")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: SagaaTheme.primaryAccent))

            Divider().opacity(0.6)

            Toggle(isOn: $state.autoPaste) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("တိုက်ရိုက် စာရိုက်သွင်းမည် (Auto-Type)")
                        .font(.system(size: 12, weight: .medium))
                    Text("Cursor ချထားသော App ထဲသို့ တိုက်ရိုက်ထည့်မည်")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: SagaaTheme.primaryAccent))

            Divider().opacity(0.6)

            Toggle(isOn: $state.launchAtLogin) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("စက်ဖွင့်လျှင် အလိုအလျောက်ဖွင့်မည်")
                        .font(.system(size: 12, weight: .medium))
                    Text("Launch at Login (Background Daemon)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: SagaaTheme.primaryAccent))
            .onChange(of: state.launchAtLogin) { newValue in
                LaunchAtLoginManager.shared.isEnabled = newValue
            }
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
                        Text("Accessibility လိုအပ်သည်")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("ခွင့်ပြုချက် ရရှိပြီး")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button("Quit Sagaa") {
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
