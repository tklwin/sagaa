import Foundation
import Accelerate
import CoreML

public final class MelSpectrogramExtractor {
    private let nFFT = 400
    private let fftSize = 512
    private let hopLength = 160
    private let nMels = 80
    private let nFreqs = 201
    private let hannWindow: [Float]
    private var melFilters: [Float] // Flattened 80 x 201
    private let cmvnMean: [Float]
    private let cmvnStd: [Float]

    public init(melFiltersURL: URL, cmvnMean: [Float], cmvnStd: [Float]) throws {
        self.cmvnMean = cmvnMean
        self.cmvnStd = cmvnStd

        // Load 80x201 filterbank
        let filterData = try Data(contentsOf: melFiltersURL)
        let matrix = try JSONDecoder().decode([[Float]].self, from: filterData)
        var flat: [Float] = []
        flat.reserveCapacity(80 * 201)
        for row in matrix {
            flat.append(contentsOf: row)
        }
        self.melFilters = flat

        // Hann window of length 400
        var window = [Float](repeating: 0, count: 400)
        vDSP_hann_window(&window, vDSP_Length(400), Int32(vDSP_HANN_NORM))
        self.hannWindow = window
    }

    /// Convert 16kHz raw audio float array into normalized MLMultiArray of shape [1, T, 80]
    public func extract(audio: [Float]) throws -> MLMultiArray {
        guard audio.count >= nFFT else {
            throw NSError(domain: "Sagaa", code: 2, userInfo: [NSLocalizedDescriptionKey: "Audio too short"])
        }

        let numFrames = (audio.count - nFFT) / hopLength + 1
        let setup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        defer {
            if let setup = setup { vDSP_DFT_DestroySetup(setup) }
        }

        var realIn = [Float](repeating: 0, count: fftSize)
        var imagIn = [Float](repeating: 0, count: fftSize)
        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)
        var powerSpectrum = [Float](repeating: 0, count: nFreqs)

        // Storage for log mel frames: [numFrames * nMels]
        var logMelData = [Float](repeating: 0, count: numFrames * nMels)

        for f in 0..<numFrames {
            let start = f * hopLength

            // Apply Hann window and pad to 512
            for i in 0..<nFFT {
                realIn[i] = audio[start + i] * hannWindow[i]
            }
            for i in nFFT..<fftSize {
                realIn[i] = 0.0
            }
            imagIn.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0.0) }

            // Execute FFT
            realIn.withUnsafeBufferPointer { rIn in
                imagIn.withUnsafeBufferPointer { iIn in
                    realOut.withUnsafeMutableBufferPointer { rOut in
                        imagOut.withUnsafeMutableBufferPointer { iOut in
                            if let setup = setup {
                                vDSP_DFT_Execute(setup, rIn.baseAddress!, iIn.baseAddress!, rOut.baseAddress!, iOut.baseAddress!)
                            }
                        }
                    }
                }
            }

            // Power spectrum = real^2 + imag^2 for 0..<201 bins
            for k in 0..<nFreqs {
                powerSpectrum[k] = (realOut[k] * realOut[k]) + (imagOut[k] * imagOut[k])
            }

            // Matrix multiply: melFilters [80 x 201] * powerSpectrum [201 x 1] -> [80 x 1]
            let frameMelOffset = f * nMels
            for m in 0..<nMels {
                var sum: Float = 0.0
                let filterOffset = m * nFreqs
                vDSP_dotpr(&powerSpectrum, 1, &melFilters[filterOffset], 1, &sum, vDSP_Length(nFreqs))

                // Log clamp
                let logEnergy = logf(max(sum, 1e-5))

                // CMVN normalization: (x - mean) / (std + 1e-9)
                let norm = (logEnergy - cmvnMean[m]) / (cmvnStd[m] + 1e-9)
                logMelData[frameMelOffset + m] = norm
            }
        }

        // Wrap into MLMultiArray of shape [1, numFrames, 80]
        let shape: [NSNumber] = [1, NSNumber(value: numFrames), NSNumber(value: nMels)]
        let multiArray = try MLMultiArray(shape: shape, dataType: .float32)
        let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: logMelData.count)
        for i in 0..<logMelData.count {
            ptr[i] = logMelData[i]
        }

        return multiArray
    }
}

