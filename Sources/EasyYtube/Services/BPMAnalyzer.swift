import Foundation

/// Best-effort BPM (tempo) estimator: decodes a segment of audio to raw PCM via
/// the bundled ffmpeg, then runs a classic energy-based beat detector (Patin's
/// algorithm) over it. This is an approximation — like any automatic tempo
/// detector it can be thrown off by tempo changes, sparse beats, or ambient
/// tracks — not a substitute for a dedicated DJ/analysis tool.
enum BPMAnalyzer {
    static func detect(fileURL: URL) -> Int? {
        guard let samples = decodePCM(fileURL: fileURL) else { return nil }
        return estimateBPM(samples: samples, sampleRate: 11025)
    }

    private static func decodePCM(fileURL: URL) -> [Float]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: BundledTools.ffmpegPath)
        // Analizza un minuto a partire dai 20s (salta intro/silenzi iniziali spesso privi di beat).
        process.arguments = [
            "-v", "quiet",
            "-ss", "20", "-t", "60",
            "-i", fileURL.path,
            "-ac", "1", "-ar", "11025",
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

        guard process.terminationStatus == 0, data.count >= MemoryLayout<Float>.size * 11025 * 5 else {
            return nil
        }

        let count = data.count / MemoryLayout<Float>.size
        var samples = [Float](repeating: 0, count: count)
        _ = samples.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        return samples
    }

    private static func estimateBPM(samples: [Float], sampleRate: Int) -> Int? {
        let windowSize = 1024
        var energies: [Float] = []
        energies.reserveCapacity(samples.count / windowSize)

        var i = 0
        while i + windowSize <= samples.count {
            var sum: Float = 0
            for j in i..<(i + windowSize) {
                sum += samples[j] * samples[j]
            }
            energies.append(sum)
            i += windowSize
        }
        guard energies.count > 50 else { return nil }

        let windowsPerSecond = Double(sampleRate) / Double(windowSize)
        let historyLen = max(4, Int(windowsPerSecond))
        let minGapWindows = max(1, Int(windowsPerSecond * 60.0 / 200.0)) // no faster than 200 BPM

        var beatIndices: [Int] = []
        var lastBeatIndex = -minGapWindows

        for idx in historyLen..<energies.count {
            let history = energies[(idx - historyLen)..<idx]
            let avg = history.reduce(0, +) / Float(history.count)
            guard avg > 0 else { continue }
            let variance = history.reduce(Float(0)) { $0 + ($1 - avg) * ($1 - avg) } / Float(history.count)
            let sensitivity = (-0.0025714 * variance) + 1.5142857 // Patin's empirical formula
            let threshold = max(1.05, min(sensitivity, 3.0))

            if energies[idx] > threshold * avg, idx - lastBeatIndex >= minGapWindows {
                beatIndices.append(idx)
                lastBeatIndex = idx
            }
        }

        guard beatIndices.count >= 4 else { return nil }

        let intervalsSeconds = zip(beatIndices, beatIndices.dropFirst())
            .map { Double($1 - $0) * Double(windowSize) / Double(sampleRate) }

        var bpmSamples: [Double] = intervalsSeconds.compactMap { interval in
            guard interval > 0 else { return nil }
            var bpm = 60.0 / interval
            while bpm < 70 { bpm *= 2 }
            while bpm > 180 { bpm /= 2 }
            return bpm
        }
        guard !bpmSamples.isEmpty else { return nil }

        bpmSamples.sort()
        let median = bpmSamples[bpmSamples.count / 2]
        return Int(median.rounded())
    }
}
