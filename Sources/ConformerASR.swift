import Foundation
import CoreML

private struct CMVNData: Codable {
    let mean: [Float]
    let std: [Float]
}

public final class ConformerASR {
    public let model: MLModel
    public let cmvnMean: [Float]
    public let cmvnStd: [Float]
    public let decoder: CTCDecoder

    public init(modelURL: URL, cmvnURL: URL, vocabURL: URL) throws {
        let compiledURL: URL
        if modelURL.pathExtension == "mlmodelc" {
            compiledURL = modelURL
        } else {
            compiledURL = try MLModel.compileModel(at: modelURL)
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all // Utilize Apple Neural Engine (ANE) + GPU
        self.model = try MLModel(contentsOf: compiledURL, configuration: config)

        let cmvnData = try Data(contentsOf: cmvnURL)
        let cmvn = try JSONDecoder().decode(CMVNData.self, from: cmvnData)
        self.cmvnMean = cmvn.mean
        self.cmvnStd = cmvn.std

        self.decoder = try CTCDecoder(vocabURL: vocabURL)
    }

    /// Run inference on normalized Mel-Spectrogram features [1, T, 80]
    public func transcribe(mel: MLMultiArray) throws -> String {
        let inputFeature = try MLDictionaryFeatureProvider(dictionary: ["mel": mel])
        let prediction = try model.prediction(from: inputFeature)

        // Find logits feature
        guard let outputName = prediction.featureNames.first,
              let logitsFeature = prediction.featureValue(for: outputName)?.multiArrayValue else {
            throw NSError(domain: "Sagaa", code: 1, userInfo: [NSLocalizedDescriptionKey: "No logits output found from CoreML model"])
        }

        return decoder.decode(logits: logitsFeature)
    }
}

