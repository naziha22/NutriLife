import SwiftUI
import Network

/// Traduction dynamique selon la langue choisie dans l'app (fr / en / ar).
func L(_ key: String) -> String {
    let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "fr"
    if let path = Bundle.main.path(forResource: lang, ofType: "lproj"), let b = Bundle(path: path) {
        return b.localizedString(forKey: key, value: key, table: nil)
    }
    return key
}

func appLocale() -> Locale { Locale(identifier: UserDefaults.standard.string(forKey: "appLanguage") ?? "fr") }

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

enum DateKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func string(_ d: Date) -> String { formatter.string(from: d) }
    static func date(_ s: String) -> Date? { formatter.date(from: s) }
}

extension UIApplication {
    var topViewController: UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

func isCancel(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    return (error as? URLError)?.code == .cancelled
}

final class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    private let monitor = NWPathMonitor()
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.isConnected = path.status == .satisfied }
        }
        monitor.start(queue: DispatchQueue(label: "nutrilife.network"))
    }
}

/// Centralise les erreurs non bloquantes (ex. écriture Firestore) affichées en toast.
final class ErrorCenter: ObservableObject {
    static let shared = ErrorCenter()
    @Published var message: String?
    func post(_ text: String) {
        DispatchQueue.main.async {
            self.message = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { if self.message == text { self.message = nil } }
        }
    }
}

final class Router: ObservableObject { @Published var tab: AppTab = .home }

enum Validator {
    static func email(_ v: String) -> String? {
        let t = v.trimmed
        if t.isEmpty { return L("val.email.required") }
        let r = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return t.range(of: r, options: .regularExpression) == nil ? L("val.email.invalid") : nil
    }
    static func password(_ v: String) -> String? {
        if v.isEmpty { return L("val.password.required") }
        if v.count < 8 { return L("val.password.short") }
        if v.rangeOfCharacter(from: .letters) == nil || v.rangeOfCharacter(from: .decimalDigits) == nil { return L("val.password.weak") }
        return nil
    }
    static func name(_ v: String) -> String? {
        let t = v.trimmed
        if t.isEmpty { return L("val.name.required") }
        return t.count < 2 ? L("val.name.short") : nil
    }
    static func confirm(_ p: String, _ c: String) -> String? { p == c ? nil : L("val.confirm.mismatch") }
}
