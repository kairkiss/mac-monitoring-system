import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: AppLanguage

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        currentLanguage = AppLanguage(rawValue: saved) ?? .chinese
    }

    func setLanguage(_ lang: AppLanguage) {
        currentLanguage = lang
        UserDefaults.standard.set(lang.rawValue, forKey: "appLanguage")
    }
}
