import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var isAvailable = false
    @Published var latestVersion = ""
    @Published var notes = ""
    @Published var downloadURL: URL?

    private let manifestURL = URL(string: "https://raw.githubusercontent.com/dgcompress/easy-ytube/main/version.json")!

    private struct VersionManifest: Decodable {
        let version: String
        let url: String
        let notes: String?
    }

    func check() {
        Task {
            do {
                var request = URLRequest(url: manifestURL)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let (data, _) = try await URLSession.shared.data(for: request)
                let manifest = try JSONDecoder().decode(VersionManifest.self, from: data)

                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
                if Self.isNewer(manifest.version, than: currentVersion) {
                    latestVersion = manifest.version
                    notes = manifest.notes ?? ""
                    downloadURL = URL(string: manifest.url)
                    isAvailable = true
                }
            } catch {
                // Nessuna connessione o repository non raggiungibile: non disturbare l'utente.
            }
        }
    }

    func dismiss() {
        isAvailable = false
    }

    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = versionTuple(candidate)
        let b = versionTuple(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func versionTuple(_ v: String) -> [Int] {
        v.split(separator: ".").map { Int($0) ?? 0 }
    }
}
