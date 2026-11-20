import SwiftUI

// MARK: - Images distantes

struct RemoteImage: View {
    let urlString: String?
    var preview = false
    var body: some View {
        let url = urlString.flatMap { URL(string: preview ? $0 + "/preview" : $0) }
        AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.25))) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill().transition(.opacity)
            case .failure: placeholder(systemName: "fork.knife")
            default: placeholder(systemName: nil)
            }
        }
    }
    private func placeholder(systemName: String?) -> some View {
        ZStack {
            AppColor.greenSoft
            if let systemName { Image(systemName: systemName).font(.title).foregroundStyle(AppColor.green.opacity(0.6)) }
            else { ProgressView() }
        }
    }
}

// MARK: - RecipeCard

struct RecipeCard: View {
    let recipe: RecipeSummary
    var width: CGFloat? = 170
    @EnvironmentObject var favorites: FavoritesViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: recipe) {
                VStack(alignment: .leading, spacing: 0) {
                    RemoteImage(urlString: recipe.thumbnail, preview: true)
                        .frame(height: 130).frame(maxWidth: .infinity).clipped()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.name).font(.subheadline.weight(.semibold)).lineLimit(2, reservesSpace: true)
                            .multilineTextAlignment(.leading).foregroundStyle(.primary)
                        if let c = recipe.category {
                            Label(c, systemImage: "leaf.fill").font(.caption2).foregroundStyle(AppColor.green)
                        }
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: width).cardStyle().clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }.buttonStyle(.plain)

            let fav = favorites.isFavorite(recipe.id)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { favorites.toggle(recipe) }
            } label: {
                Image(systemName: fav ? "heart.fill" : "heart")
                    .symbolEffect(.bounce, value: fav)
                    .foregroundStyle(fav ? Color.red : .primary)
                    .padding(8).background(.ultraThinMaterial, in: Circle())
            }.padding(8)
        }
        .frame(width: width)
    }
}

// MARK: - CategoryCard

struct CategoryCard: View {
    let category: Category
    var isSelected = false
    var body: some View {
        VStack(spacing: 6) {
            RemoteImage(urlString: category.thumbnail).frame(width: 64, height: 64).clipShape(Circle())
                .overlay(Circle().stroke(isSelected ? AppColor.accent : .clear, lineWidth: 3))
            Text(category.name).font(.caption.weight(.medium)).lineLimit(1).foregroundStyle(.primary)
        }
        .frame(width: 80).scaleEffect(isSelected ? 1.06 : 1).animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - SearchBar

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $text).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
            if !text.isEmpty {
                Button { withAnimation { text = "" } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            }
        }
        .padding(12).background(AppColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - CustomButton

struct CustomButton: View {
    enum Style { case primary, accent, secondary }
    let title: String
    var icon: String? = nil
    var style: Style = .primary
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading { ProgressView().tint(foreground) }
                else if let icon { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(style == .secondary ? Color.secondary.opacity(0.3) : .clear))
        }
        .disabled(isLoading)
        .buttonStyle(PressStyle())
    }
    private var foreground: Color { style == .secondary ? .primary : .white }
    private var background: Color {
        switch style { case .primary: return AppColor.green; case .accent: return AppColor.accent; case .secondary: return AppColor.card }
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1).opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - États (chargement / vide / erreur)

struct LoadingView: View {
    var message: String? = nil
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large).tint(AppColor.green)
            Text(message ?? L("common.loading")).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

struct EmptyStateView: View {
    let icon: String; let title: String; let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @State private var appear = false
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 48)).foregroundStyle(AppColor.green)
                .padding(24).background(AppColor.greenSoft, in: Circle()).scaleEffect(appear ? 1 : 0.6)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let actionTitle, let action { CustomButton(title: actionTitle, style: .accent, action: action).frame(maxWidth: 240).padding(.top, 6) }
        }
        .padding(30).frame(maxWidth: .infinity)
        .opacity(appear ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appear = true } }
    }
}

struct ErrorView: View {
    let message: String
    var retry: (() -> Void)? = nil
    var body: some View {
        EmptyStateView(icon: "exclamationmark.triangle.fill", title: L("err.title"), message: message,
                       actionTitle: retry == nil ? nil : L("common.retry"), action: retry)
    }
}

struct OfflineBanner: View {
    var body: some View {
        Label(L("home.offline"), systemImage: "wifi.slash").font(.footnote.weight(.medium)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(10).background(AppColor.accent, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View { Text(title).font(.title3.weight(.bold)).padding(.horizontal) }
}

// MARK: - Champ de formulaire avec validation

struct AppTextField: View {
    let title: String; let icon: String
    @Binding var text: String
    var isSecure = false
    var error: String? = nil
    var keyboard: UIKeyboardType = .default
    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote.weight(.medium)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(AppColor.green).frame(width: 22)
                Group {
                    if isSecure && !reveal { SecureField(title, text: $text) }
                    else { TextField(title, text: $text).keyboardType(keyboard).textInputAutocapitalization(keyboard == .emailAddress ? .never : .words).autocorrectionDisabled(keyboard == .emailAddress) }
                }
                if isSecure {
                    Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye").foregroundStyle(.secondary) }
                }
            }
            .padding(14).background(AppColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(error == nil ? Color.clear : Color.red.opacity(0.7), lineWidth: 1.5))
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }.animation(.easeOut(duration: 0.2), value: error)
    }
}

// MARK: - CustomTabBar

struct CustomTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: selection == tab ? tab.iconFilled : tab.icon).font(.system(size: 19))
                            .symbolEffect(.bounce, value: selection == tab)
                        Text(L(tab.titleKey)).font(.system(size: 10, weight: .medium)).lineLimit(1)
                    }
                    .foregroundStyle(selection == tab ? AppColor.green : Color.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background {
                        if selection == tab { Capsule().fill(AppColor.greenSoft).matchedGeometryEffect(id: "tabBG", in: ns) }
                    }
                }.buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 14).padding(.bottom, 4)
    }
}
