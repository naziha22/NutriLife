import SwiftUI
import FirebaseFirestore

@MainActor
final class PlannerViewModel: ObservableObject {
    @Published var meals: [PlannedMeal] = []
    @Published var selectedDate = Date()
    @Published var weekOffset = 0
    private var listener: ListenerRegistration?
    private var uid: String?

    private var calendar: Calendar { var c = Calendar.current; c.locale = appLocale(); return c }

    var weekDays: [Date] {
        let base = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date()
        guard let start = calendar.dateInterval(of: .weekOfYear, for: base)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func shiftWeek(_ delta: Int) {
        weekOffset += delta
        if let first = weekDays.first { selectedDate = first }
    }

    func start(uid: String) {
        guard uid != self.uid else { return }
        stop(); self.uid = uid
        listener = FirestoreService.shared.listen("mealPlans", uid: uid) { [weak self] docs in
            let parsed = docs.compactMap { d -> PlannedMeal? in
                let x = d.data()
                guard let date = x["date"] as? String, let slotRaw = x["slot"] as? String, let slot = MealSlot(rawValue: slotRaw),
                      let rid = x["recipeId"] as? String, let name = x["name"] as? String else { return nil }
                let r = RecipeSummary(id: rid, name: name, thumbnail: x["thumbnail"] as? String, category: (x["category"] as? String)?.nonEmpty)
                return PlannedMeal(id: d.documentID, date: date, slot: slot, recipe: r)
            }
            Task { @MainActor in self?.meals = parsed }
        }
    }

    func stop() { listener?.remove(); listener = nil; uid = nil; meals = [] }

    func meal(on date: Date, slot: MealSlot) -> PlannedMeal? {
        let key = DateKey.string(date)
        return meals.first { $0.date == key && $0.slot == slot }
    }
    func meals(on date: Date) -> [PlannedMeal] {
        let key = DateKey.string(date)
        return meals.filter { $0.date == key }.sorted { $0.slot.rawValue < $1.slot.rawValue }
    }
    var weekMeals: [PlannedMeal] {
        let keys = Set(weekDays.map(DateKey.string))
        return meals.filter { keys.contains($0.date) }
    }

    /// Ajout ou modification : l'identifiant (uid_date_slot) garantit un seul repas par créneau.
    func set(_ r: RecipeSummary, on date: Date, slot: MealSlot) {
        guard let uid else { return }
        let key = DateKey.string(date)
        FirestoreService.shared.set("mealPlans", id: "\(uid)_\(key)_\(slot.rawValue)", data: [
            "userId": uid, "date": key, "slot": slot.rawValue, "recipeId": r.id, "name": r.name,
            "thumbnail": r.thumbnail ?? "", "category": r.category ?? ""
        ], merge: false)
    }

    func remove(_ meal: PlannedMeal) {
        meals.removeAll { $0.id == meal.id }
        FirestoreService.shared.delete("mealPlans", id: meal.id)
    }
}
