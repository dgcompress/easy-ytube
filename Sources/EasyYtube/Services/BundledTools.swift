import Foundation

/// Locates the yt-dlp / ffmpeg binaries bundled with the app, whether running
/// from a packaged .app (Contents/Resources/bin) or from `swift run` during
/// development (Resources/bin at the project root).
enum BundledTools {
    static var ytDlpPath: String { resolve("bin/yt-dlp", executable: true) }
    static var ffmpegPath: String { resolve("bin/ffmpeg", executable: true) }
    static var denoPath: String { resolve("bin/deno", executable: true) }
    static var coverImagePath: String { resolve("Cover.png", executable: false) }

    private static func resolve(_ relativePath: String, executable: Bool) -> String {
        func isValid(_ path: String) -> Bool {
            executable ? FileManager.default.isExecutableFile(atPath: path) : FileManager.default.fileExists(atPath: path)
        }

        if let resourceURL = Bundle.main.resourceURL {
            let candidate = resourceURL.appendingPathComponent(relativePath)
            if isValid(candidate.path) {
                return candidate.path
            }
        }

        var dir = Bundle.main.executableURL?.deletingLastPathComponent()
        for _ in 0..<8 {
            guard let current = dir else { break }
            let candidate = current.appendingPathComponent("Resources").appendingPathComponent(relativePath)
            if isValid(candidate.path) {
                return candidate.path
            }
            dir = current.deletingLastPathComponent()
        }

        fatalError("Risorsa bundlata non trovata: \(relativePath)")
    }
}
