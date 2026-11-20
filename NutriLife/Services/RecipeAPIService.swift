import Foundation

enum APIError: LocalizedError {
    case invalidURL, offline, http(Int), decoding
    var errorDescription: String? {
        switch self {
        case .invalidURL: return L("err.generic")
        case .offline: return L("err.offline")
        case .http: return L("err.server")
        case .decoding: return L("err.decoding")
        }
    }
}

/// Client TheMealDB (https://www.themealdb.com/api.php) — URLSession + async/await + Codable.
struct RecipeAPIService {
    static let shared = RecipeAPIService()
    private let base = "https://www.themealdb.com/api/json/v1/1/"

    private func fetch<T: Decodable>(_ endpoint: String, _ query: [URLQueryItem] = []) async throws -> T {
        var comps = URLComponents(string: base + endpoint)
        if !query.isEmpty { comps?.queryItems = query }
        guard let url = comps?.url else { throw APIError.invalidURL }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let h = response as? HTTPURLResponse, !(200..<300).contains(h.statusCode) { throw APIError.http(h.statusCode) }
            do { return try JSONDecoder().decode(T.self, from: data) } catch { throw APIError.decoding }
        } catch let e as APIError {
            throw e
        } catch let e as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost].contains(e.code) {
            throw APIError.offline
        }
    }

    func search(name: String) async throws -> [Recipe] {
        let r: MealsResponse<Recipe> = try await fetch("search.php", [URLQueryItem(name: "s", value: name)])
        return r.meals ?? []
    }
    func search(firstLetter: String) async throws -> [RecipeSummary] {
        let r: MealsResponse<Recipe> = try await fetch("search.php", [URLQueryItem(name: "f", value: firstLetter)])
        return (r.meals ?? []).map(\.summary)
    }
    func lookup(id: String) async throws -> Recipe? {
        let r: MealsResponse<Recipe> = try await fetch("lookup.php", [URLQueryItem(name: "i", value: id)])
        return r.meals?.first
    }
    func byIngredient(_ ingredient: String) async throws -> [RecipeSummary] {
        let value = ingredient.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "_")
        let r: MealsResponse<MealFilterDTO> = try await fetch("filter.php", [URLQueryItem(name: "i", value: value)])
        return (r.meals ?? []).map(\.summary)
    }
    func byCategory(_ category: String) async throws -> [RecipeSummary] {
        let r: MealsResponse<MealFilterDTO> = try await fetch("filter.php", [URLQueryItem(name: "c", value: category)])
        return (r.meals ?? []).map { var s = $0.summary; s.category = category; return s }
    }
    func categories() async throws -> [Category] {
        let r: CategoriesResponse = try await fetch("categories.php")
        return r.categories
    }
    func randomMeals(count: Int) async throws -> [RecipeSummary] {
        try await withThrowingTaskGroup(of: Recipe?.self) { group in
            for _ in 0..<count {
                group.addTask {
                    let r: MealsResponse<Recipe> = try await self.fetch("random.php")
                    return r.meals?.first
                }
            }
            var seen = Set<String>(); var out: [RecipeSummary] = []
            for try await r in group { if let r, seen.insert(r.id).inserted { out.append(r.summary) } }
            return out
        }
    }
}
