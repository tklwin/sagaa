import Foundation
import AVFoundation

public final class AudioEngine {
    private let engine = AVAudioEngine()
    private var isRecording = false
    private var audioBuffer: [Float] = []
    private let lock = NSLock()

    public init() {}

    /// Start capturing 16kHz mono audio from default microphone
    public func startRecording(onAudioLevel: ((Float) -> Void)? = nil) throws {
        lock.lock()
        audioBuffer.removeAll()
        isRecording = true
        lock.unlock()

        let inputNode = engine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        // Target: 16000Hz, 1 channel
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: 16000,
                                               channels: 1,
                                               interleaved: false) else {
            throw NSError(domain: "Sagaa", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create target audio format"])
        }

        guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
            throw NSError(domain: "Sagaa", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] buffer, _ in
            guard let self = self, self.isRecording else { return }

            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * 16000.0 / nativeFormat.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if let channelData = convertedBuffer.floatChannelData?[0] {
                let count = Int(convertedBuffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: channelData, count: count))

                self.lock.lock()
                self.audioBuffer.append(contentsOf: samples)
                self.lock.unlock()

                // Calculate RMS energy level for UI visualization
                if let onAudioLevel = onAudioLevel, count > 0 {
                    var sum: Float = 0
                    for s in samples { sum += s * s }
                    let rms = sqrt(sum / Float(count))
                    DispatchQueue.main.async {
                        onAudioLevel(rms)
                    }
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

