import SwiftUI

enum AppColor {
    static let green = Color(red: 0.16, green: 0.50, blue: 0.30)
    static let greenDark = Color(red: 0.10, green: 0.36, blue: 0.22)
    static let accent = Color(red: 0.98, green: 0.62, blue: 0.30)   // orange doux
    static let greenSoft = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.13, green: 0.23, blue: 0.16, alpha: 1)
        : UIColor(red: 0.89, green: 0.95, blue: 0.90, alpha: 1) })
    static let background = Color(UIColor.systemGroupedBackground)
    static let card = Color(UIColor.secondarySystemGroupedBackground)
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.background(AppColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}
extension View { func cardStyle() -> some View { modifier(CardStyle()) } }

enum AppTab: String, CaseIterable, Identifiable {
    case home, favorites, planner, shopping, profile
    var id: String { rawValue }
    var titleKey: String { "tab.\(rawValue)" }
    var icon: String {
        switch self {
        case .home: return "house"
        case .favorites: return "heart"
        case .planner: return "calendar"
        case .shopping: return "cart"
        case .profile: return "person"
        }
    }
    var iconFilled: String { icon + ".fill" }
}
