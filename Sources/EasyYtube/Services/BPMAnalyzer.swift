import Foundation

/// Best-effort BPM (tempo) estimator: decodes a chunk of audio to raw PCM via
/// the bundled ffmpeg, builds an onset/novelty curve from its energy, then finds
/// the dominant beat period by autocorrelating that curve. Autocorrelation looks
/// at the whole analyzed segment at once rather than picking beats one at a time
/// off a threshold, so it holds up much better on tracks with uneven dynamics —
/// but like any lightweight automatic tempo detector it's still an approximation,
/// not a substitute for a dedicated DJ/analysis tool.
enum BPMAnalyzer {
    private static let sampleRate = 22050
    private static let hopSize = 512 // ~23ms per finestra di energia

    static func detect(fileURL: URL) -> Int? {
        guard let samples = decodePCM(fileURL: fileURL) else { return nil }
        return estimateBPM(samples: samples)
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

    private static func estimateBPM(samples: [Float]) -> Int? {
        guard samples.count > hopSize * 100 else { return nil }

        // 1. Curva di energia per finestra (~23ms di risoluzione).
        var energies: [Float] = []
        energies.reserveCapacity(samples.count / hopSize)
        var i = 0
        while i + hopSize <= samples.count {
            var sum: Float = 0
            for j in i..<(i + hopSize) {
                sum += samples[j] * samples[j]
            }
            energies.append(sum)
            i += hopSize
        }
        guard energies.count > 200 else { return nil }

        // 2. Curva di novelty: solo gli incrementi positivi di energia (probabili
        // attacchi/beat), che è ciò che l'autocorrelazione deve poi periodicizzare.
        var novelty = [Float](repeating: 0, count: energies.count)
        for k in 1..<energies.count {
            novelty[k] = max(0, energies[k] - energies[k - 1])
        }
        let mean = novelty.reduce(0, +) / Float(novelty.count)
        for k in 0..<novelty.count { novelty[k] -= mean }

        // 3. Autocorrelazione della novelty per ogni lag corrispondente a un
        // tempo fra 60 e 200 BPM: il lag col punteggio più alto è il periodo
        // di beat dominante nel brano.
        let framesPerSecond = Double(sampleRate) / Double(hopSize)
        let minBPM = 60.0
        let maxBPM = 200.0
        let minLag = max(1, Int((60.0 / maxBPM) * framesPerSecond))
        let maxLag = min(novelty.count - 1, Int((60.0 / minBPM) * framesPerSecond))
        guard maxLag > minLag else { return nil }

        var bestLag = minLag
        var bestScore: Float = -.greatestFiniteMagnitude
        for lag in minLag...maxLag {
            var score: Float = 0
            var count = 0
            var idx = 0
            while idx + lag < novelty.count {
                score += novelty[idx] * novelty[idx + lag]
                count += 1
                idx += 1
            }
            guard count > 0 else { continue }
            score /= Float(count)
            if score > bestScore {
                bestScore = score
                bestLag = lag
            }
        }

        var bpm = 60.0 * framesPerSecond / Double(bestLag)

        // Piega ottave/sottottave (metà o doppio tempo hanno spesso correlazione
        // comparabile) verso l'intervallo di percezione più naturale.
        while bpm < 80 { bpm *= 2 }
        while bpm > 175 { bpm /= 2 }

        return Int(bpm.rounded())
    }
}
