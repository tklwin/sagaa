import Foundation
import CoreML

public final class ConformerASR {
    public let model: MLModel
    public let decoder: CTCDecoder

    public init(modelURL: URL, vocabURL: URL) throws {
        let compiledURL: URL
        if modelURL.pathExtension == "mlmodelc" {
            compiledURL = modelURL
        } else {
            compiledURL = try MLModel.compileModel(at: modelURL)
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all // Utilize Apple Neural Engine (ANE) + GPU
        self.model = try MLModel(contentsOf: compiledURL, configuration: config)
        self.decoder = try CTCDecoder(vocabURL: vocabURL)
    }

    /// Run inference directly on raw 16kHz audio samples
    public func transcribe(audio: [Float]) throws -> String {
        guard audio.count >= 8000 else { return "" }

        let shape: [NSNumber] = [1, NSNumber(value: audio.count)]
        let audioArray = try MLMultiArray(shape: shape, dataType: .float32)
        let ptr = audioArray.dataPointer.bindMemory(to: Float.self, capacity: audio.count)
        for i in 0..<audio.count {
            ptr[i] = audio[i]
        }

        let inputFeature = try MLDictionaryFeatureProvider(dictionary: ["audio": audioArray])
        let prediction = try model.prediction(from: inputFeature)

        // Find logits feature
        guard let outputName = prediction.featureNames.first,
              let logitsFeature = prediction.featureValue(for: outputName)?.multiArrayValue else {
            throw NSError(domain: "Sagaa", code: 1, userInfo: [NSLocalizedDescriptionKey: "No logits output found from CoreML model"])
        }

        return decoder.decode(logits: logitsFeature)
    }
}
