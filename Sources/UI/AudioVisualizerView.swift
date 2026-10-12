import SwiftUI

public struct AudioVisualizerView: View {
    public let level: Float
    public let isRecording: Bool

    public init(level: Float, isRecording: Bool) {
        self.level = level
        self.isRecording = isRecording
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<16, id: \.self) { index in
                barView(index: index)
            }
        }
        .frame(height: 28)
    }

    private func barView(index: Int) -> some View {
        let baseHeight: CGFloat = isRecording ? 6 : 3
        let wave = sin(Double(index) * 0.45)
        let dynamicHeight: CGFloat = isRecording ?
            CGFloat(max(Double(level * 55.0) * (0.6 + 0.4 * wave), 4.0)) : baseHeight

        return RoundedRectangle(cornerRadius: 1.5)
            .fill(isRecording ? SagaaTheme.recordingRed : Color.secondary.opacity(0.4))
            .frame(width: 3, height: min(max(dynamicHeight, baseHeight), 28))
            .animation(.easeInOut(duration: 0.1), value: dynamicHeight)
    }
}

