import SwiftUI
import FirebaseFirestore

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var items: [RecipeSummary] = []
    @Published var isLoading = false
    private var listener: ListenerRegistration?
    private var uid: String?

    func start(uid: String) {
        guard uid != self.uid else { return }
        stop(); self.uid = uid; isLoading = true
        listener = FirestoreService.shared.listen("favorites", uid: uid) { [weak self] docs in
            let parsed = docs.compactMap { d -> (RecipeSummary, Date)? in
                let x = d.data()
                guard let id = x["recipeId"] as? String, let name = x["name"] as? String else { return nil }
                return (RecipeSummary(id: id, name: name, thumbnail: x["thumbnail"] as? String, category: x["category"] as? String),
                        (x["createdAt"] as? Timestamp)?.dateValue() ?? Date())
            }.sorted { $0.1 > $1.1 }.map(\.0)
            Task { @MainActor in self?.items = parsed; self?.isLoading = false }
        }
    }

    func stop() { listener?.remove(); listener = nil; uid = nil; items = [] }

    func isFavorite(_ id: String) -> Bool { items.contains { $0.id == id } }

    func toggle(_ r: RecipeSummary) {
        guard let uid else { return }
        let docID = "\(uid)_\(r.id)"
        if isFavorite(r.id) {
            items.removeAll { $0.id == r.id }
            FirestoreService.shared.delete("favorites", id: docID)
        } else {
            items.insert(r, at: 0)
            FirestoreService.shared.set("favorites", id: docID, data: [
                "userId": uid, "recipeId": r.id, "name": r.name,
                "thumbnail": r.thumbnail ?? "", "category": r.category ?? "", "createdAt": Timestamp(date: Date())
            ])
        }
    }
}
