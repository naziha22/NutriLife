import Foundation

struct NutritionFacts { var calories: Double; var protein: Double; var carbs: Double; var fat: Double }

/// TheMealDB ne fournit AUCUNE donnée nutritionnelle. L'app n'invente donc jamais de valeurs :
/// le fournisseur par défaut renvoie `nil` et l'UI affiche « non disponible ».
/// Pour brancher une source fiable (USDA FoodData Central, Edamam, Nutritionix…), implémenter ce protocole
/// et remplacer `NutritionService.provider`.
protocol NutritionProviding {
    func facts(for recipe: Recipe) async -> NutritionFacts?
}

struct UnavailableNutritionProvider: NutritionProviding {
    func facts(for recipe: Recipe) async -> NutritionFacts? { nil }
}

enum NutritionService {
    static var provider: NutritionProviding = UnavailableNutritionProvider()
}
