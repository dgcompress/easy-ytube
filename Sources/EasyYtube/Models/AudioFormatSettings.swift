import Foundation

enum OutputContainer: String, CaseIterable, Identifiable {
    case mp3 = "Audio MP3"
    case mp4 = "Video MP4"

    var id: String { rawValue }

    var caption: String {
        switch self {
        case .mp3: return "Audio compresso, compatibile ovunque"
        case .mp4: return "Video con audio incluso"
        }
    }
}

enum EncodingMode: String, CaseIterable, Identifiable {
    case bitrate = "Codifica"
    case quality = "Qualità"

    var id: String { rawValue }
}

enum VideoQuality: String, CaseIterable, Identifiable {
    case max = "Massima"
    case uhd4K = "4K"
    case fullHD = "Full HD"

    var id: String { rawValue }

    /// Altezza massima da passare al selettore di formato di yt-dlp; nil = nessun limite.
    var heightCap: Int? {
        switch self {
        case .max: return nil
        case .uhd4K: return 2160
        case .fullHD: return 1080
        }
    }
}

struct AudioFormatSettings {
    var container: OutputContainer = .mp3
    var encodingMode: EncodingMode = .bitrate
    var bitrateKbps: Int = 320
    /// Scala di libmp3lame: 0 = migliore, 9 = peggiore. Di default la migliore qualità.
    var vbrQuality: Int = 0
    var sampleRate: Int = 48000
    var videoQuality: VideoQuality = .max

    static let availableBitrates = [320, 256, 192, 128, 96]
    static let availableSampleRates = [44100, 48000]
}
