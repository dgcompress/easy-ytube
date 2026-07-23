import Foundation

/// Locates the yt-dlp / ffmpeg binaries bundled with the app, whether running
/// from a packaged .app (Contents/Resources/bin) or from `swift run` during
/// development (Resources/bin at the project root).
enum BundledTools {
    static var ytDlpPath: String { resolve("yt-dlp") }
    static var ffmpegPath: String { resolve("ffmpeg") }
    static var denoPath: String { resolve("deno") }

    private static func resolve(_ name: String) -> String {
        if let resourceURL = Bundle.main.resourceURL {
            let candidate = resourceURL.appendingPathComponent("bin/\(name)")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate.path
            }
        }

        var dir = Bundle.main.executableURL?.deletingLastPathComponent()
        for _ in 0..<8 {
            guard let current = dir else { break }
            let candidate = current.appendingPathComponent("Resources/bin/\(name)")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate.path
            }
            dir = current.deletingLastPathComponent()
        }

        fatalError("Strumento bundlato non trovato: \(name)")
    }
}
