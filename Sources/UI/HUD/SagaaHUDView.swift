import SwiftUI
import AppKit

public struct SagaaHUDView: View {
    @ObservedObject public var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Left Status Icon
            ZStack {
                if state.isTranscribing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                        .frame(width: 22, height: 22)
                } else if state.isRecording {
                    Circle()
                        .fill(SagaaTheme.recordingRed)
                        .frame(width: 12, height: 12)
                        .shadow(color: SagaaTheme.recordingRed.opacity(0.8), radius: 6, x: 0, y: 0)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .frame(width: 22, height: 22)

            // Center: Waveform or status text
            if state.isRecording {
                HStack(spacing: 3) {
                    ForEach(0..<14, id: \.self) { index in
                        waveformBar(index: index)
                    }
                }
                .frame(width: 80, height: 20)

                Text("Listening...")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            } else if state.isTranscribing {
                Text("Transcribing...")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Text(state.autoPaste ? "Pasted!" : "Copied!")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }

            Spacer(minLength: 4)

            // Right: Shortcut hint
            Text("⌃⌥S")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.12))
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .frame(minWidth: 230, maxWidth: 260, minHeight: 46, maxHeight: 46)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.75))
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
    }

    private func waveformBar(index: Int) -> some View {
        let normalizedLevel = min(max(CGFloat(state.audioLevel) * 8.0, 0.15), 1.0)
        let variation = sin(Double(index) * 0.7) * 0.35 + 0.65
        let height = max(4.0, 18.0 * normalizedLevel * CGFloat(variation))

        return RoundedRectangle(cornerRadius: 1.5)
            .fill(
                LinearGradient(
                    colors: [SagaaTheme.primaryAccent, SagaaTheme.recordingRed],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 2.5, height: height)
            .animation(.easeInOut(duration: 0.08), value: state.audioLevel)
    }
}
