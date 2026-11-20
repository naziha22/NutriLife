import Foundation

// MARK: - Recettes (TheMealDB)

struct RecipeSummary: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let thumbnail: String?
    var category: String?
    init(id: String, name: String, thumbnail: String?, category: String? = nil) {
        self.id = id; self.name = name; self.thumbnail = thumbnail; self.category = category
    }
}

struct Ingredient: Identifiable, Hashable {
    let name: String
    let measure: String
    var id: String { name + "|" + measure }
}

struct Category: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let thumbnail: String?
    let description: String?
    enum CodingKeys: String, CodingKey {
        case id = "idCategory", name = "strCategory", thumbnail = "strCategoryThumb", description = "strCategoryDescription"
    }
}

/// Réponse générique : `{ "meals": [...] }` ou `{ "meals": null }`
struct MealsResponse<T: Decodable>: Decodable { let meals: [T]? }
struct CategoriesResponse: Decodable { let categories: [Category] }
struct MealFilterDTO: Decodable {
    let idMeal: String; let strMeal: String; let strMealThumb: String?
    var summary: RecipeSummary { RecipeSummary(id: idMeal, name: strMeal, thumbnail: strMealThumb) }
}

struct Recipe: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let category: String?
    let area: String?
    let instructions: String
    let thumbnail: String?
    let tags: [String]
    let youtube: String?
    let ingredients: [Ingredient]

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        func s(_ k: String) -> String? {
            guard let key = Key(stringValue: k) else { return nil }
            let v = (try? c.decodeIfPresent(String.self, forKey: key)) ?? nil
            guard let t = v?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
            return t
        }
        guard let id = s("idMeal"), let name = s("strMeal") else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Missing idMeal"))
        }
        self.id = id; self.name = name
        self.category = s("strCategory"); self.area = s("strArea")
        self.instructions = s("strInstructions") ?? ""
        self.thumbnail = s("strMealThumb")
        self.youtube = s("strYoutube")
        self.tags = (s("strTags") ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        var list: [Ingredient] = []
        for i in 1...20 {
            if let n = s("strIngredient\(i)") { list.append(Ingredient(name: n, measure: s("strMeasure\(i)") ?? "")) }
        }
        self.ingredients = list
    }

    var summary: RecipeSummary { RecipeSummary(id: id, name: name, thumbnail: thumbnail, category: category) }

    /// Étapes de préparation nettoyées ("STEP 1", "1." etc. retirés).
    var steps: [String] {
        var lines = instructions.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        lines = lines.filter { $0.range(of: #"^(?i)step\s*\d+\.?$"#, options: .regularExpression) == nil && $0.range(of: #"^\d+\.?$"#, options: .regularExpression) == nil }
        lines = lines.map { $0.replacingOccurrences(of: #"^\d+[.)]\s*"#, with: "", options: .regularExpression) }
        if lines.count <= 1, let only = lines.first {
            return only.components(separatedBy: ". ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.map { $0.hasSuffix(".") ? $0 : $0 + "." }
        }
        return lines
    }
}

// MARK: - Quantités

struct ParsedMeasure { var value: Double?; var unit: String }

enum MeasureParser {
    static func number(_ t: String) -> Double? {
        if t.contains("/") {
            let p = t.split(separator: "/")
            if p.count == 2, let a = Double(p[0]), let b = Double(p[1]), b != 0 { return a / b }
            return nil
        }
        return Double(t)
    }
    static func parse(_ raw: String) -> ParsedMeasure {
        var tokens = raw.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return ParsedMeasure(value: nil, unit: "") }
        var total = 0.0; var found = false
        while let t = tokens.first, let v = number(t) { total += v; found = true; tokens.removeFirst() }
        if !found, let first = tokens.first {
            let digits = first.prefix { $0.isNumber || $0 == "." }
            if !digits.isEmpty, let v = Double(digits) {
                total = v; found = true
                let rest = String(first.dropFirst(digits.count))
                if rest.isEmpty { tokens.removeFirst() } else { tokens[0] = rest }
            }
        }
        return ParsedMeasure(value: found ? total : nil, unit: tokens.joined(separator: " ").lowercased())
    }
    /// Convertit kg→g et l→ml pour pouvoir regrouper les quantités compatibles.
    static func normalized(_ p: ParsedMeasure) -> ParsedMeasure {
        guard let v = p.value else { return p }
        switch p.unit {
        case "kg": return ParsedMeasure(value: v * 1000, unit: "g")
        case "g", "gram", "grams": return ParsedMeasure(value: v, unit: "g")
        case "l", "litre", "litres": return ParsedMeasure(value: v * 1000, unit: "ml")
        case "ml": return ParsedMeasure(value: v, unit: "ml")
        case "tbs", "tbsp", "tablespoon", "tablespoons": return ParsedMeasure(value: v, unit: "tbsp")
        case "tsp", "teaspoon", "teaspoons": return ParsedMeasure(value: v, unit: "tsp")
        default: return p
        }
    }
    static func format(_ p: ParsedMeasure, factor: Double = 1) -> String {
        guard let v = p.value else { return p.unit }
        let s = v * factor
        let txt = abs(s - s.rounded()) < 0.05 ? String(Int(s.rounded())) : String(format: "%.1f", s)
        return p.unit.isEmpty ? txt : "\(txt) \(p.unit)"
    }
}

// MARK: - Planning & courses

enum MealSlot: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner
    var id: String { rawValue }
    var titleKey: String { "slot.\(rawValue)" }
    var icon: String {
        switch self { case .breakfast: return "sunrise.fill"; case .lunch: return "sun.max.fill"; case .dinner: return "moon.stars.fill" }
    }
}

struct PlannedMeal: Identifiable, Hashable {
    let id: String
    let date: String   // yyyy-MM-dd
    let slot: MealSlot
    let recipe: RecipeSummary
}

struct ShoppingItem: Identifiable, Hashable {
    let id: String
    var name: String
    var quantityText: String
    var isChecked: Bool
    var isManual: Bool
}
