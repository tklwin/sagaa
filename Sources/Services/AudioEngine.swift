import Foundation
import AVFoundation

public final class AudioEngine {
    private let engine = AVAudioEngine()
    private var isRecording = false
    private var audioBuffer: [Float] = []
    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    public init() {}

    /// Start capturing 16kHz mono audio from default microphone
    public func startRecording(onAudioLevel: ((Float) -> Void)? = nil) throws {
        lock.lock()
        audioBuffer.removeAll()
        isRecording = true
        lock.unlock()

        let inputNode = engine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: 16000,
                                         channels: 1,
                                         interleaved: false) else {
            throw NSError(domain: "Sagaa", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create target audio format"])
        }
        self.targetFormat = target

        if nativeFormat.sampleRate == 16000 && nativeFormat.channelCount == 1 {
            self.converter = nil
        } else {
            guard let conv = AVAudioConverter(from: nativeFormat, to: target) else {
                throw NSError(domain: "Sagaa", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
            }
            self.converter = conv
        }

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: nativeFormat) { [weak self] buffer, _ in
            guard let self = self, self.isRecording else { return }

            var samples: [Float] = []

            if let converter = self.converter, let targetFormat = self.targetFormat {
                let ratio = 16000.0 / nativeFormat.sampleRate
                let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

                var isConsumed = false
                var error: NSError?
                converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    if isConsumed {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    isConsumed = true
                    outStatus.pointee = .haveData
                    return buffer
                }

                if let channelData = convertedBuffer.floatChannelData?[0] {
                    let count = Int(convertedBuffer.frameLength)
                    samples = Array(UnsafeBufferPointer(start: channelData, count: count))
                }
            } else {
                if let channelData = buffer.floatChannelData?[0] {
                    let count = Int(buffer.frameLength)
                    samples = Array(UnsafeBufferPointer(start: channelData, count: count))
                }
            }

            guard !samples.isEmpty else { return }

            self.lock.lock()
            self.audioBuffer.append(contentsOf: samples)
            self.lock.unlock()

            if let onAudioLevel = onAudioLevel {
                var sum: Float = 0
                for s in samples { sum += s * s }
                let rms = sqrt(sum / Float(samples.count))
                DispatchQueue.main.async {
                    onAudioLevel(rms)
                }
            }
        }

        try engine.start()
    }

    /// Stop capturing and return recorded 16kHz float samples
    public func stopRecording() -> [Float] {
        lock.lock()
        isRecording = false
        let captured = audioBuffer
        audioBuffer.removeAll()
        lock.unlock()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        return captured
    }
}
