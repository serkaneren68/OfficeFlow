import Foundation

enum SupportedLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .system:
            return Locale.autoupdatingCurrent.identifier
        case .english:
            return "en"
        case .turkish:
            return "tr"
        }
    }

    var titleKey: String {
        switch self {
        case .system: return "language.system"
        case .english: return "language.english"
        case .turkish: return "language.turkish"
        }
    }

    var fallbackTitle: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .turkish: return "Turkish"
        }
    }
}

enum AppLocalization {
    static let languagePreferenceKey = "preferredLanguageCode"

    static func selectedLanguage() -> SupportedLanguage {
        let raw = UserDefaults.standard.string(forKey: languagePreferenceKey) ?? SupportedLanguage.system.rawValue
        return SupportedLanguage(rawValue: raw) ?? .system
    }

    static func locale(for language: SupportedLanguage = selectedLanguage()) -> Locale {
        Locale(identifier: language.localeIdentifier)
    }

    private static func bundleForCode(_ code: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }

    static func bundle(for language: SupportedLanguage = selectedLanguage()) -> Bundle {
        switch language {
        case .system:
            let preferredCodes = Locale.preferredLanguages.map {
                $0.components(separatedBy: "-").first ?? $0
            } + ["Base", "en"]
            for code in preferredCodes {
                if let localizedBundle = bundleForCode(code) {
                    return localizedBundle
                }
            }
            return .main
        case .english:
            if let englishBundle = bundleForCode("en") {
                return englishBundle
            }
            if let baseBundle = bundleForCode("Base") {
                return baseBundle
            }
            return .main
        case .turkish:
            if let turkishBundle = bundleForCode("tr") {
                return turkishBundle
            }
            return bundle(for: .english)
        }
    }

    static func text(_ key: String, fallback: String? = nil) -> String {
        let value = fallback ?? key
        let language = selectedLanguage()

        switch language {
        case .turkish:
            guard let turkishBundle = bundleForCode("tr") else { return value }
            return NSLocalizedString(key, tableName: "Localizable", bundle: turkishBundle, value: value, comment: "")
        case .english:
            // English source strings are the fallback values in code.
            return value
        case .system:
            let preferredCode = Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "en"
            if preferredCode == "tr", let turkishBundle = bundleForCode("tr") {
                return NSLocalizedString(key, tableName: "Localizable", bundle: turkishBundle, value: value, comment: "")
            }
            return value
        }
    }

    static func format(_ key: String, _ args: CVarArg..., fallback: String? = nil) -> String {
        let format = text(key, fallback: fallback)
        return String(format: format, locale: locale(), arguments: args)
    }
}
