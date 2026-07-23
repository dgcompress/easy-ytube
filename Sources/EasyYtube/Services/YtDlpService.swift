import Foundation

struct VideoInfo {
    let id: String
    let title: String
    let thumbnailURL: URL?
    let webpageURL: URL
}

final class YtDlpService {
    enum ServiceError: Error, LocalizedError {
        case processFailed(String)
        case noResult
        case cancelled

        var errorDescription: String? {
            switch self {
            case .processFailed(let message): return message
            case .noResult: return "Nessun risultato da yt-dlp"
            case .cancelled: return "Download annullato"
            }
        }
    }

    private var activeProcesses: [UUID: Process] = [:]
    private var cancelledIDs: Set<UUID> = []

    /// Terminates the yt-dlp process for a given download, if still running.
    func cancelDownload(id: UUID) {
        cancelledIDs.insert(id)
        activeProcesses[id]?.terminate()
    }

    /// Resolves title/thumbnail/URL for a single video or every entry of a playlist,
    /// without downloading anything.
    func fetchInfo(for url: URL) async throws -> [VideoInfo] {
        let output = try await run(arguments: [
            "--dump-json",
            "--flat-playlist",
            "--no-warnings",
            "--no-playlist",
            "--js-runtimes", "deno:\(BundledTools.denoPath)",
            url.absoluteString
        ])

        let infos: [VideoInfo] = output
            .split(separator: "\n")
            .compactMap { line in
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return nil
                }
                let title = (json["title"] as? String) ?? "Video"
                let thumbnail = (json["thumbnail"] as? String).flatMap(URL.init(string:))
                let videoID = (json["id"] as? String) ?? url.absoluteString
                let webpage: URL
                if let webpageString = json["webpage_url"] as? String, let resolved = URL(string: webpageString) {
                    webpage = resolved
                } else if let id = json["id"] as? String {
                    webpage = URL(string: "https://www.youtube.com/watch?v=\(id)")!
                } else {
                    webpage = url
                }
                return VideoInfo(id: videoID, title: title, thumbnailURL: thumbnail, webpageURL: webpage)
            }

        guard !infos.isEmpty else { throw ServiceError.noResult }
        return infos
    }

    /// Downloads + converts one item, reporting progress (0...1) and current speed string.
    func download(
        id: UUID,
        url: URL,
        settings: AudioFormatSettings,
        destination: URL,
        onProgress: @escaping (Double, String) -> Void
    ) async throws -> URL {
        var arguments = baseArguments(destination: destination)

        switch settings.container {
        case .mp3:
            arguments += ["-x", "--audio-format", "mp3"]
            switch settings.encodingMode {
            case .bitrate:
                arguments += ["--audio-quality", "\(settings.bitrateKbps)K"]
            case .quality:
                arguments += ["--audio-quality", "\(settings.vbrQuality)"]
            }
            arguments += ["--postprocessor-args", "ffmpeg:-ar \(settings.sampleRate)"]
        case .mp4:
            // Preferisce H.264+AAC (compatibile con qualsiasi player/editor, incluso
            // Premiere); VP9/Opus in mp4 sono validi ma pochissimo supportati fuori
            // dal browser, quindi restano solo come ultima spiaggia.
            let heightFilter = settings.videoQuality.heightCap.map { "[height<=\($0)]" } ?? ""
            let compatible = "bestvideo[vcodec^=avc1]\(heightFilter)+bestaudio[acodec^=mp4a]/best[vcodec^=avc1]\(heightFilter)"
            let fallback = "bestvideo\(heightFilter)+bestaudio/best\(heightFilter)"
            arguments += [
                "-f", "\(compatible)/\(fallback)",
                "--merge-output-format", "mp4",
                "--embed-thumbnail"
            ]
        }

        arguments.append(url.absoluteString)

        var fileURL = try await runWithProgress(id: id, arguments: arguments, onProgress: onProgress)

        // Copertina dell'app al posto della miniatura del video e tag BPM,
        // solo per l'audio (il video tiene la propria copertina, embeddata
        // sopra tramite --embed-thumbnail, e non ha un BPM da analizzare).
        if settings.container == .mp3 {
            let bpm = BPMAnalyzer.detect(fileURL: fileURL)
            embedAppCover(fileURL: fileURL, bpm: bpm)
            if let bpm {
                fileURL = (try? appendBPM(bpm, to: fileURL)) ?? fileURL
            }
        }

        return fileURL
    }

    private func baseArguments(destination: URL) -> [String] {
        [
            "--newline",
            "--no-warnings",
            "--no-playlist",
            "--js-runtimes", "deno:\(BundledTools.denoPath)",
            "--ffmpeg-location", BundledTools.ffmpegPath,
            "--add-metadata",
            "-o", destination.appendingPathComponent("%(title)s.%(ext)s").path
        ]
    }

    /// Remuxes in the app's own cover art in place of whatever thumbnail yt-dlp
    /// would otherwise have embedded, and (if available) writes the detected BPM
    /// as a proper ID3 TBPM frame so DJ software (Rekordbox, previews, etc.) can
    /// read it directly from the file's metadata, not just the filename.
    /// Best-effort: leaves the file untouched on any failure rather than losing
    /// the download over a cosmetic step.
    private func embedAppCover(fileURL: URL, bpm: Int?) {
        let tempURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent + "_cover_tmp")
            .appendingPathExtension(fileURL.pathExtension)

        var arguments = [
            "-y", "-v", "error",
            "-i", fileURL.path,
            "-i", BundledTools.coverImagePath,
            "-map", "0:a",
            "-map", "1",
            "-c", "copy",
            "-id3v2_version", "3",
            "-metadata:s:v", "title=Album cover",
            "-metadata:s:v", "comment=Cover (front)",
            "-disposition:v", "attached_pic"
        ]
        if let bpm {
            arguments += ["-metadata", "TBPM=\(bpm)"]
        }
        arguments.append(tempURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: BundledTools.ffmpegPath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                try? FileManager.default.removeItem(at: tempURL)
                return
            }
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    private func appendBPM(_ bpm: Int, to fileURL: URL) throws -> URL {
        let ext = fileURL.pathExtension
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let newURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("\(baseName) \(bpm) bpm")
            .appendingPathExtension(ext)
        try FileManager.default.moveItem(at: fileURL, to: newURL)
        return newURL
    }

    /// Re-downloads the latest yt-dlp release in place (`yt-dlp -U`), keeping the
    /// extractor working when YouTube changes something upstream.
    func selfUpdate() async throws {
        _ = try await run(arguments: ["-U"])
    }

    // MARK: - Process plumbing

    private func run(arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: BundledTools.ytDlpPath)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Drain both pipes as data arrives; yt-dlp's JSON output can exceed the
            // pipe buffer, and reading only at termination deadlocks the child process.
            var stdoutData = Data()
            var stderrData = Data()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { stdoutData.append(data) }
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { stderrData.append(data) }
            }

            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: String(data: stdoutData, encoding: .utf8) ?? "")
                } else {
                    let message = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: ServiceError.processFailed(message?.isEmpty == false ? message! : "yt-dlp è terminato con un errore"))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func runWithProgress(
        id: UUID,
        arguments: [String],
        onProgress: @escaping (Double, String) -> Void
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: BundledTools.ytDlpPath)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let progressRegex = try! NSRegularExpression(
                pattern: #"\[download\]\s+([\d.]+)% of.*?at\s+([\d.]+\S+/s|Unknown speed)"#
            )
            let destinationRegex = try! NSRegularExpression(
                pattern: #"\[(?:ExtractAudio|download)\] Destination: (.+)"#
            )
            let mergerRegex = try! NSRegularExpression(
                pattern: #"\[Merger\] Merging formats into "(.+)""#
            )
            let alreadyRegex = try! NSRegularExpression(
                pattern: #"\[download\] (.+) has already been downloaded"#
            )

            var finalPath: String?
            var errorOutput = ""
            var stdoutBuffer = ""

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                stdoutBuffer += chunk
                while let newlineRange = stdoutBuffer.range(of: "\n") {
                    let line = String(stdoutBuffer[stdoutBuffer.startIndex..<newlineRange.lowerBound])
                    stdoutBuffer.removeSubrange(stdoutBuffer.startIndex..<newlineRange.upperBound)

                    let full = NSRange(line.startIndex..., in: line)
                    if let match = progressRegex.firstMatch(in: line, range: full),
                       let pctRange = Range(match.range(at: 1), in: line) {
                        let percent = Double(line[pctRange]) ?? 0
                        let speedRange = Range(match.range(at: 2), in: line)
                        let speed = speedRange.map { String(line[$0]) } ?? ""
                        onProgress(percent / 100.0, speed)
                    } else if let match = mergerRegex.firstMatch(in: line, range: full),
                              let pathRange = Range(match.range(at: 1), in: line) {
                        finalPath = String(line[pathRange])
                    } else if let match = destinationRegex.firstMatch(in: line, range: full),
                              let pathRange = Range(match.range(at: 1), in: line) {
                        finalPath = String(line[pathRange])
                    } else if let match = alreadyRegex.firstMatch(in: line, range: full),
                              let pathRange = Range(match.range(at: 1), in: line) {
                        finalPath = String(line[pathRange])
                    }
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                errorOutput += chunk
            }

            process.terminationHandler = { [weak self] proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                self?.activeProcesses[id] = nil
                let wasCancelled = self?.cancelledIDs.remove(id) != nil

                if wasCancelled {
                    continuation.resume(throwing: ServiceError.cancelled)
                } else if proc.terminationStatus == 0, let path = finalPath {
                    continuation.resume(returning: URL(fileURLWithPath: path))
                } else if proc.terminationStatus == 0 {
                    continuation.resume(throwing: ServiceError.processFailed("Download completato ma il percorso del file non è stato rilevato"))
                } else {
                    let message = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: ServiceError.processFailed(message.isEmpty ? "yt-dlp è terminato con un errore" : message))
                }
            }

            do {
                try process.run()
                activeProcesses[id] = process
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
