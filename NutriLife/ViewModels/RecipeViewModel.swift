import SwiftUI

@MainActor
final class RecipeViewModel: ObservableObject {
    enum State: Equatable { case idle, loading, loaded, failed(String) }
    @Published var state: State = .idle
    @Published var categories: [Category] = []
    @Published var popular: [RecipeSummary] = []
    @Published var recommended: [RecipeSummary] = []
    @Published var recents: [RecipeSummary] = []
    private let api = RecipeAPIService.shared
    private let recentsKey = "recentRecipes"

    init() {
        if let data = UserDefaults.standard.data(forKey: recentsKey),
           let list = try? JSONDecoder().decode([RecipeSummary].self, from: data) { recents = list }
    }

    func loadHome(force: Bool = false) async {
        if state == .loaded && !force { return }
        state = .loading
        let pref = UserDefaults.standard.string(forKey: "preferredCategory") ?? ""
        let letter = String("abcmpst".randomElement() ?? "c")
        do {
            async let cats = api.categories()
            async let pop = api.search(firstLetter: letter)
            async let rec = recommendedMeals(pref)
            let (c, p, r) = try await (cats, pop, rec)
            categories = c; popular = Array(p.prefix(10)); recommended = r
            state = .loaded
        } catch {
            state = isCancel(error) ? .idle : .failed(error.localizedDescription)
        }
    }

    private func recommendedMeals(_ pref: String) async throws -> [RecipeSummary] {
        if pref.isEmpty { return try await api.randomMeals(count: 8) }
        return Array(try await api.byCategory(pref).shuffled().prefix(10))
    }

    func markViewed(_ r: RecipeSummary) {
        recents.removeAll { $0.id == r.id }
        recents.insert(r, at: 0)
        recents = Array(recents.prefix(12))
        if let data = try? JSONEncoder().encode(recents) { UserDefaults.standard.set(data, forKey: recentsKey) }
    }
}

@MainActor
final class SearchViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable { case name, ingredient; var id: String { rawValue } }
    @Published var query = ""
    @Published var mode: Mode = .name
    @Published var category: String?
    @Published var results: [RecipeSummary] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasSearched = false
    private let api = RecipeAPIService.shared

    init(category: String?) { self.category = category }
    var key: String { "\(mode.rawValue)|\(query)|\(category ?? "")" }

    /// Appelée via `.task(id: key)` : annulée automatiquement à chaque frappe (debounce 350 ms).
    func run() async {
        try? await Task.sleep(for: .milliseconds(350))
        if Task.isCancelled { return }
        let q = query.trimmed
        if q.isEmpty && category == nil { results = []; hasSearched = false; error = nil; isLoading = false; return }
        isLoading = true; error = nil
        do {
            var list: [RecipeSummary]
            if q.isEmpty, let c = category {
                list = try await api.byCategory(c)
            } else if mode == .name {
                let recipes = try await api.search(name: q)
                list = recipes.filter { category == nil || $0.category == category }.map(\.summary)
            } else {
                list = try await api.byIngredient(q)
                if let c = category {
                    let inCategory = try await api.byCategory(c)
                    let ids = Set(inCategory.map(\.id))
                    list = list.filter { ids.contains($0.id) }
                }
            }
            if Task.isCancelled { return }
            results = list; hasSearched = true; isLoading = false
        } catch {
            if isCancel(error) { return }
            self.error = error.localizedDescription; isLoading = false
        }
    }
}
