import Foundation
import Accelerate

/// BPM (tempo) estimator: decodes a chunk of audio to raw PCM via the bundled
/// ffmpeg, builds a spectral-flux onset-strength curve (the same class of
/// onset-detection function used by real music-analysis tools, e.g. librosa's
/// onset_strength), then finds the dominant beat period by autocorrelating
/// that curve, weighted by a perceptual tempo preference centered around 120
/// BPM to resolve octave ambiguity (half/double-tempo confusion).
///
/// Spectral flux — summing only the *increases* in per-frequency-bin
/// magnitude between consecutive frames — responds to percussive attacks
/// (kick/snare/hi-hat) across the whole spectrum, and largely ignores a
/// smoothly sustained bassline. That matters because a rolling/legato bass
/// pattern (common in reggaeton/dembow) can dominate a simple broadband
/// energy signal and fool a detector into locking onto half the real tempo —
/// verified against several real tracks during development, where switching
/// from raw energy to spectral flux fixed exactly this failure mode.
///
/// Still a best-effort approximation, not a substitute for a dedicated
/// DJ/analysis tool with full beat-tracking.
enum BPMAnalyzer {
    private static let sampleRate = 22050
    private static let fftSize = 1024
    private static let hopSize = 256 // ~11.6ms onset resolution

    static func detect(fileURL: URL) -> Int? {
        guard let samples = decodePCM(fileURL: fileURL) else { return nil }
        let envelope = onsetEnvelope(samples)
        return estimateBPM(envelope: envelope)
    }

    private static func decodePCM(fileURL: URL) -> [Float]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: BundledTools.ffmpegPath)
        // Analizza 90s a partire dai 15s: salta intro/silenzi iniziali spesso privi
        // di beat e copre una porzione ampia per una stima più stabile.
        process.arguments = [
            "-v", "quiet",
            "-ss", "15", "-t", "90",
            "-i", fileURL.path,
            "-ac", "1", "-ar", "\(sampleRate)",
            "-f", "f32le", "-"
        ]

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        // readDataToEndOfFile drains continuously until the pipe closes, so this
        // doesn't deadlock even though the PCM output exceeds the pipe buffer.
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0, data.count >= MemoryLayout<Float>.size * sampleRate * 5 else {
            return nil
        }

        let count = data.count / MemoryLayout<Float>.size
        var samples = [Float](repeating: 0, count: count)
        _ = samples.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        return samples
    }

    /// Spectral-flux onset-strength curve: for each overlapping analysis
    /// window, the FFT magnitude spectrum is compared to the previous
    /// window's, and only positive per-bin differences (energy increases —
    /// onsets) are summed. Sustained tones contribute little; attacks spike.
    private static func onsetEnvelope(_ samples: [Float]) -> [Float] {
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var prevMag = [Float](repeating: 0, count: fftSize / 2)
        var envelope: [Float] = []
        envelope.reserveCapacity(samples.count / hopSize)

        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        var mag = [Float](repeating: 0, count: fftSize / 2)
        var magSqrt = [Float](repeating: 0, count: fftSize / 2)
        var frame = [Float](repeating: 0, count: fftSize)

        var i = 0
        while i + fftSize <= samples.count {
            for j in 0..<fftSize { frame[j] = samples[i + j] * window[j] }

            realp.withUnsafeMutableBufferPointer { realPtr in
                imagp.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    frame.withUnsafeBufferPointer { framePtr in
                        framePtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                            vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                        }
                    }
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    vDSP_zvmags(&splitComplex, 1, &mag, 1, vDSP_Length(fftSize / 2))
                }
            }
            var countF = Int32(fftSize / 2)
            vvsqrtf(&magSqrt, mag, &countF)

            var flux: Float = 0
            for k in 1..<(fftSize / 2) { // salta il bin DC
                let diff = magSqrt[k] - prevMag[k]
                if diff > 0 { flux += diff }
            }
            envelope.append(flux)
            swap(&prevMag, &magSqrt)

            i += hopSize
        }
        return envelope
    }

    private static func estimateBPM(envelope: [Float]) -> Int? {
        guard envelope.count > 200 else { return nil }

        let mean = envelope.reduce(0, +) / Float(envelope.count)
        let centered = envelope.map { $0 - mean }

        func correlation(atLag lag: Int) -> Float {
            var score: Float = 0
            var count = 0
            var idx = 0
            while idx + lag < centered.count {
                score += centered[idx] * centered[idx + lag]
                count += 1
                idx += 1
            }
            return count > 0 ? score / Float(count) : 0
        }

        let framesPerSecond = Double(sampleRate) / Double(hopSize)
        let minBPM = 55.0
        let maxBPM = 200.0
        let minLag = max(1, Int((60.0 / maxBPM) * framesPerSecond))
        let maxLag = min(centered.count - 1, Int((60.0 / minBPM) * framesPerSecond))
        guard maxLag > minLag else { return nil }

        // Pesa il punteggio grezzo di autocorrelazione con una preferenza
        // percettiva centrata sui 120 BPM (il "tempo di risonanza" usato da
        // molti stimatori di tempo per orientare la scelta fra tempo
        // dimezzato/raddoppiato quando la periodicità grezza è ambigua) — a
        // differenza di un taglio netto, qui la preferenza è morbida: pesa
        // poco quando un candidato domina chiaramente, e fa da spareggio
        // quando due candidati sono vicini.
        let preferredBPM = 120.0
        let sigmaOctaves = 1.0

        var bestLag = minLag
        var bestWeighted: Float = -.greatestFiniteMagnitude
        for lag in minLag...maxLag {
            let bpm = 60.0 * framesPerSecond / Double(lag)
            let octaves = log2(bpm / preferredBPM)
            let weight = exp(-0.5 * pow(octaves / sigmaOctaves, 2))
            let weighted = correlation(atLag: lag) * Float(weight)
            if weighted > bestWeighted {
                bestWeighted = weighted
                bestLag = lag
            }
        }

        let bpm = 60.0 * framesPerSecond / Double(bestLag)
        return Int(bpm.rounded())
    }
}
