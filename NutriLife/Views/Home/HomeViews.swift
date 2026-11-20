import SwiftUI

struct SearchRoute: Hashable { var category: String? }

struct HomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var vm: RecipeViewModel
    @EnvironmentObject var network: NetworkMonitor

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    NavigationLink(value: SearchRoute(category: nil)) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            Text(L("home.search.placeholder")).foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "slider.horizontal.3").foregroundStyle(AppColor.accent)
                        }
                        .padding(14).background(AppColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    }.buttonStyle(.plain).padding(.horizontal)

                    if !network.isConnected { OfflineBanner().padding(.horizontal) }

                    if vm.state == .loading && vm.categories.isEmpty {
                        LoadingView()
                    } else if case .failed(let message) = vm.state, vm.categories.isEmpty {
                        ErrorView(message: message) { Task { await vm.loadHome(force: true) } }
                    } else {
                        content
                    }
                }.padding(.vertical)
            }
            .background(AppColor.background)
            .refreshable { await vm.loadHome(force: true) }
            .navigationDestination(for: RecipeSummary.self) { RecipeDetailView(summary: $0) }
            .navigationDestination(for: SearchRoute.self) { SearchView(category: $0.category) }
            .navigationDestination(for: String.self) { _ in NutritionDashboardView() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: "nutrition") { Image(systemName: "chart.pie.fill").foregroundStyle(AppColor.green) }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // Bannière publicitaire en bas de l'écran d'accueil (ID de test)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BannerAdView().frame(width: 320, height: 50).frame(maxWidth: .infinity).background(.bar)
            }
            .task { await vm.loadHome() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: L("home.welcome"), auth.displayName)).font(.system(size: 28, weight: .bold, design: .rounded))
            Text(L("home.subtitle")).font(.subheadline).foregroundStyle(.secondary)
        }.padding(.horizontal)
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: L("home.categories"))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(vm.categories.enumerated()), id: \.element.id) { i, c in
                        NavigationLink(value: SearchRoute(category: c.name)) { CategoryCard(category: c) }.buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(i) * 0.03), value: vm.categories.count)
                    }
                }.padding(.horizontal)
            }
        }
        recipeRow(L("home.popular"), vm.popular)
        recipeRow(L("home.recommended"), vm.recommended)
        if !vm.recents.isEmpty { recipeRow(L("home.recent"), vm.recents) }
    }

    @ViewBuilder private func recipeRow(_ title: String, _ list: [RecipeSummary]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: title)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) { ForEach(list) { RecipeCard(recipe: $0) } }.padding(.horizontal).padding(.vertical, 4)
                }
            }
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var home: RecipeViewModel
    @StateObject private var vm: SearchViewModel
    init(category: String?) { _vm = StateObject(wrappedValue: SearchViewModel(category: category)) }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SearchBar(text: $vm.query, placeholder: vm.mode == .name ? L("search.placeholder.name") : L("search.placeholder.ingredient"))
                Picker("", selection: $vm.mode) {
                    Text(L("search.mode.name")).tag(SearchViewModel.Mode.name)
                    Text(L("search.mode.ingredient")).tag(SearchViewModel.Mode.ingredient)
                }.pickerStyle(.segmented)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(L("search.all"), selected: vm.category == nil) { vm.category = nil }
                        ForEach(home.categories) { c in chip(c.name, selected: vm.category == c.name) { vm.category = vm.category == c.name ? nil : c.name } }
                    }
                }

                if vm.isLoading { LoadingView() }
                else if let e = vm.error { ErrorView(message: e) { Task { await vm.run() } } }
                else if !vm.hasSearched { EmptyStateView(icon: "magnifyingglass", title: L("search.start.title"), message: L("search.start.msg")) }
                else if vm.results.isEmpty { EmptyStateView(icon: "fork.knife", title: L("search.empty.title"), message: L("search.empty.msg")) }
                else {
                    HStack { Text(String(format: L("search.results"), vm.results.count)).font(.footnote).foregroundStyle(.secondary); Spacer() }
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(vm.results) { RecipeCard(recipe: $0, width: nil).transition(.scale(scale: 0.9).combined(with: .opacity)) }
                    }
                }
            }.padding().animation(.easeInOut(duration: 0.25), value: vm.results)
        }
        .background(AppColor.background)
        .navigationTitle(L("search.title")).navigationBarTitleDisplayMode(.inline)
        .task(id: vm.key) { await vm.run() }
        .task { await home.loadHome() }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.spring(response: 0.3)) { action() } } label: {
            Text(title).font(.footnote.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(selected ? .white : .primary)
                .background(selected ? AppColor.green : AppColor.card, in: Capsule())
        }.buttonStyle(.plain)
    }
}

struct FavoritesView: View {
    @EnvironmentObject var favorites: FavoritesViewModel
    @State private var query = ""
    @EnvironmentObject var router: Router
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var filtered: [RecipeSummary] {
        let q = query.trimmed.lowercased()
        return q.isEmpty ? favorites.items : favorites.items.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !favorites.items.isEmpty { SearchBar(text: $query, placeholder: L("fav.search")) }
                    if favorites.isLoading && favorites.items.isEmpty { LoadingView() }
                    else if favorites.items.isEmpty {
                        EmptyStateView(icon: "heart.slash", title: L("fav.empty.title"), message: L("fav.empty.msg"),
                                       actionTitle: L("fav.empty.action")) { router.tab = .home }
                    } else if filtered.isEmpty {
                        EmptyStateView(icon: "magnifyingglass", title: L("search.empty.title"), message: L("search.empty.msg"))
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) { ForEach(filtered) { RecipeCard(recipe: $0, width: nil) } }
                    }
                }.padding().animation(.easeInOut(duration: 0.25), value: filtered)
            }
            .background(AppColor.background)
            .navigationTitle(L("fav.title"))
            .navigationDestination(for: RecipeSummary.self) { RecipeDetailView(summary: $0) }
        }
    }
}
