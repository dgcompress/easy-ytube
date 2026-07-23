import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case it
    case en

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .it: return "IT"
        case .en: return "EN"
        }
    }
}

/// Runtime-switchable localization: the user can toggle language from the UI
/// without relaunching, so we load both .strings tables ourselves instead of
/// relying on Bundle.main's launch-time locale resolution.
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    private var tables: [AppLanguage: [String: String]] = [:]

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: saved) {
            language = lang
        } else {
            let systemIsItalian = Locale.preferredLanguages.first?.hasPrefix("it") == true
            language = systemIsItalian ? .it : .en
        }
        loadTables()
    }

    private func loadTables() {
        for lang in AppLanguage.allCases {
            if let url = Bundle.main.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: nil,
                localization: lang.rawValue
            ), let dict = NSDictionary(contentsOf: url) as? [String: String] {
                tables[lang] = dict
            }
        }
    }

    func string(_ key: String) -> String {
        tables[language]?[key] ?? key
    }
}

@MainActor
func L(_ key: String) -> String {
    LocalizationManager.shared.string(key)
}
