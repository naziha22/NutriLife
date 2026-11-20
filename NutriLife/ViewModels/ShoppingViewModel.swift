import SwiftUI
import FirebaseFirestore

@MainActor
final class ShoppingViewModel: ObservableObject {
    @Published var items: [ShoppingItem] = []
    @Published var isGenerating = false
    @Published var error: String?
    private var listener: ListenerRegistration?
    private var uid: String?
    private var cache: [String: Recipe] = [:]

    var remaining: [ShoppingItem] { items.filter { !$0.isChecked } }
    var purchased: [ShoppingItem] { items.filter { $0.isChecked } }

    func start(uid: String) {
        guard uid != self.uid else { return }
        stop(); self.uid = uid
        listener = FirestoreService.shared.listen("shoppingLists", uid: uid) { [weak self] docs in
            let parsed = docs.compactMap { d -> (ShoppingItem, Date)? in
                let x = d.data()
                guard let name = x["name"] as? String else { return nil }
                let item = ShoppingItem(id: d.documentID, name: name, quantityText: x["quantityText"] as? String ?? "",
                                        isChecked: x["isChecked"] as? Bool ?? false, isManual: x["isManual"] as? Bool ?? false)
                return (item, (x["createdAt"] as? Timestamp)?.dateValue() ?? Date())
            }.sorted { $0.1 < $1.1 }.map(\.0)
            Task { @MainActor in self?.items = parsed }
        }
    }
    func stop() { listener?.remove(); listener = nil; uid = nil; items = [] }

    func addManual(name: String, quantity: String) {
        guard let uid, !name.trimmed.isEmpty else { return }
        FirestoreService.shared.set("shoppingLists", id: "\(uid)_manual_\(UUID().uuidString)", data: [
            "userId": uid, "name": name.trimmed, "quantityText": quantity.trimmed,
            "isChecked": false, "isManual": true, "createdAt": Timestamp(date: Date())
        ])
    }

    func toggle(_ item: ShoppingItem) {
        guard let i = items.firstIndex(of: item) else { return }
        items[i].isChecked.toggle()
        FirestoreService.shared.set("shoppingLists", id: item.id, data: ["isChecked": items[i].isChecked])
    }

    func remove(_ item: ShoppingItem) {
        items.removeAll { $0.id == item.id }
        FirestoreService.shared.delete("shoppingLists", id: item.id)
    }

    func clearPurchased() { purchased.forEach(remove) }

    /// Génère la liste à partir des repas planifiés (aujourd'hui et après). Regroupe les ingrédients identiques
    /// dont les unités sont compatibles (g/kg, ml/l, cuillères…). Conserve l'état « acheté » et les ajouts manuels.
    func generate(from meals: [PlannedMeal]) async {
        guard let uid else { return }
        isGenerating = true; error = nil; defer { isGenerating = false }
        let today = DateKey.string(Calendar.current.startOfDay(for: Date()))
        let upcoming = meals.filter { $0.date >= today }
        do {
            let ids = Set(upcoming.map { $0.recipe.id })
            for id in ids where cache[id] == nil {
                if let r = try await RecipeAPIService.shared.lookup(id: id) { cache[id] = r }
            }
            struct Agg { var name: String; var value: Double?; var unit: String }
            var dict: [String: Agg] = [:]
            for meal in upcoming {
                guard let recipe = cache[meal.recipe.id] else { continue }
                for ing in recipe.ingredients {
                    let p = MeasureParser.normalized(MeasureParser.parse(ing.measure))
                    let key = ing.name.lowercased() + "|" + p.unit
                    if var a = dict[key] { if let v = p.value { a.value = (a.value ?? 0) + v }; dict[key] = a }
                    else { dict[key] = Agg(name: ing.name, value: p.value, unit: p.unit) }
                }
            }
            let existing = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            var newIDs = Set<String>()
            for (key, a) in dict {
                let safe = String(key.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" })
                let id = "\(uid)_gen_\(safe)"
                newIDs.insert(id)
                var data: [String: Any] = ["userId": uid, "name": a.name.prefix(1).uppercased() + a.name.dropFirst(),
                                           "quantityText": MeasureParser.format(ParsedMeasure(value: a.value, unit: a.unit)), "isManual": false]
                if existing[id] == nil { data["isChecked"] = false; data["createdAt"] = Timestamp(date: Date()) }
                FirestoreService.shared.set("shoppingLists", id: id, data: data)
            }
            for item in items where !item.isManual && !newIDs.contains(item.id) { FirestoreService.shared.delete("shoppingLists", id: item.id) }
        } catch {
            if !isCancel(error) { self.error = error.localizedDescription }
        }
    }
}
