import Foundation
import CoreML

public final class CTCDecoder {
    private let id2token: [Int: String]
    private let blankId: Int

    public init(vocabURL: URL, blankId: Int = 0) throws {
        self.blankId = blankId
        let data = try Data(contentsOf: vocabURL)
        let token2id = try JSONDecoder().decode([String: Int].self, from: data)
        
        var mapping: [Int: String] = [:]
        for (token, id) in token2id {
            mapping[id] = token
        }
        self.id2token = mapping
    }

    /// Decode output logits tensor [1, T, vocabSize] to syllable Burmese text
    public func decode(logits: MLMultiArray) -> String {
        let shape = logits.shape.map { $0.intValue }
        guard shape.count == 3 else { return "" }
        let timeSteps = shape[1]
        let vocabSize = shape[2]

        let strides = logits.strides.map { $0.intValue }
        let strideT = strides[1]
        let strideV = strides[2]

        var ids: [Int] = []
        ids.reserveCapacity(timeSteps)

        if logits.dataType == .float16 {
            let ptr = logits.dataPointer.bindMemory(to: Float16.self, capacity: logits.count)
            for t in 0..<timeSteps {
                let base = t * strideT
                var bestIdx = 0
                var maxVal = ptr[base]

                for v in 1..<vocabSize {
                    let val = ptr[base + v * strideV]
                    if val > maxVal {
                        maxVal = val
                        bestIdx = v
                    }
                }
                ids.append(bestIdx)
            }
        } else if logits.dataType == .float32 {
            let ptr = logits.dataPointer.bindMemory(to: Float.self, capacity: logits.count)
            for t in 0..<timeSteps {
                let base = t * strideT
                var bestIdx = 0
                var maxVal = ptr[base]

                for v in 1..<vocabSize {
                    let val = ptr[base + v * strideV]
                    if val > maxVal {
                        maxVal = val
                        bestIdx = v
                    }
                }
                ids.append(bestIdx)
            }
        } else if logits.dataType == .double {
            let ptr = logits.dataPointer.bindMemory(to: Double.self, capacity: logits.count)
            for t in 0..<timeSteps {
                let base = t * strideT
                var bestIdx = 0
                var maxVal = ptr[base]

                for v in 1..<vocabSize {
                    let val = ptr[base + v * strideV]
                    if val > maxVal {
                        maxVal = val
                        bestIdx = v
                    }
                }
                ids.append(bestIdx)
            }
        } else {
            // Safe fallback using MLMultiArray NSNumber subscripting
            for t in 0..<timeSteps {
                var bestIdx = 0
                var maxVal = logits[[0, t, 0] as [NSNumber]].floatValue
                for v in 1..<vocabSize {
                    let val = logits[[0, t, v] as [NSNumber]].floatValue
                    if val > maxVal {
                        maxVal = val
                        bestIdx = v
                    }
                }
                ids.append(bestIdx)
            }
        }

        // CTC greedy collapse: drop consecutive duplicates and blanks
        var out: [Int] = []
        var prev = -1
        for id in ids {
            if id != prev && id != blankId {
                out.append(id)
            }
            prev = id
        }

        let syllables = out.compactMap { id2token[$0] }.filter { !$0.isEmpty }
        return syllables.joined(separator: " ")
    }
}
