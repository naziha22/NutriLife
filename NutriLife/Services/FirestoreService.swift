import Foundation
import FirebaseFirestore

/// Accès Cloud Firestore. Collections : users, favorites, mealPlans, shoppingLists, userSettings.
/// Toute donnée personnelle contient `userId` (UID Firebase du propriétaire) — voir firestore.rules.
/// La persistance hors-ligne de Firestore est activée par défaut : lecture/écriture sans réseau, sync au retour.
final class FirestoreService {
    static let shared = FirestoreService()
    private var db: Firestore { Firestore.firestore() }

    func listen(_ collection: String, uid: String, onChange: @escaping ([QueryDocumentSnapshot]) -> Void) -> ListenerRegistration {
        db.collection(collection).whereField("userId", isEqualTo: uid).addSnapshotListener { snap, error in
            if let error { ErrorCenter.shared.post(error.localizedDescription); return }
            onChange(snap?.documents ?? [])
        }
    }

    /// Écriture non bloquante (fonctionne hors-ligne grâce au cache local).
    func set(_ collection: String, id: String, data: [String: Any], merge: Bool = true) {
        db.collection(collection).document(id).setData(data, merge: merge) { error in
            if let error { ErrorCenter.shared.post(error.localizedDescription) }
        }
    }

    func delete(_ collection: String, id: String) {
        db.collection(collection).document(id).delete { error in
            if let error { ErrorCenter.shared.post(error.localizedDescription) }
        }
    }

    func get(_ collection: String, id: String) async throws -> [String: Any]? {
        try await db.collection(collection).document(id).getDocument().data()
    }

    func saveUser(uid: String, name: String, email: String) {
        set("users", id: uid, data: ["userId": uid, "displayName": name, "email": email, "updatedAt": Timestamp(date: Date())])
    }

    func saveSettings(uid: String, theme: String, language: String, preferredCategory: String) {
        set("userSettings", id: uid, data: ["userId": uid, "theme": theme, "language": language, "preferredCategory": preferredCategory])
    }
}
