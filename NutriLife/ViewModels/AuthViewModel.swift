import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var displayName = ""
    @Published var isReady = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        // Session persistante gérée par Firebase : l'écouteur restaure l'utilisateur au lancement.
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.apply(user) }
        }
    }

    private func apply(_ user: User?) {
        self.user = user
        displayName = user?.displayName?.trimmed.nonEmpty ?? user?.email?.components(separatedBy: "@").first ?? ""
        isReady = true
    }

    func clearMessages() { errorMessage = nil; infoMessage = nil }

    func signIn(email: String, password: String) async {
        await run { _ = try await Auth.auth().signIn(withEmail: email.trimmed, password: password) }
    }

    func register(name: String, email: String, password: String) async {
        await run {
            let result = try await Auth.auth().createUser(withEmail: email.trimmed, password: password)
            let change = result.user.createProfileChangeRequest()
            change.displayName = name.trimmed
            try await change.commitChanges()
            await MainActor.run { self.displayName = name.trimmed }
        }
    }

    func signInWithGoogle() async {
        await run {
            guard let clientID = FirebaseApp.app()?.options.clientID else { throw NSError(domain: "NutriLife", code: 1) }
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            guard let root = UIApplication.shared.topViewController else { throw NSError(domain: "NutriLife", code: 2) }
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
            guard let idToken = result.user.idToken?.tokenString else { throw NSError(domain: "NutriLife", code: 3) }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            _ = try await Auth.auth().signIn(with: credential)
        }
    }

    func resetPassword(email: String) async -> Bool {
        isLoading = true; defer { isLoading = false }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email.trimmed)
            return true
        } catch { errorMessage = message(for: error); return false }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        do { try Auth.auth().signOut() } catch { errorMessage = message(for: error) }
    }

    func updateName(_ name: String) async {
        guard let user, let n = Optional(name.trimmed), Validator.name(n) == nil else { return }
        do {
            let change = user.createProfileChangeRequest()
            change.displayName = n
            try await change.commitChanges()
            displayName = n
            FirestoreService.shared.saveUser(uid: user.uid, name: n, email: user.email ?? "")
        } catch { errorMessage = message(for: error) }
    }

    /// Récupère thème / langue / préférence sauvegardés dans Firestore (userSettings/{uid}).
    func syncSettings() async {
        guard let user else { return }
        FirestoreService.shared.saveUser(uid: user.uid, name: displayName, email: user.email ?? "")
        if let d = try? await FirestoreService.shared.get("userSettings", id: user.uid) {
            let ud = UserDefaults.standard
            if let v = d["theme"] as? String { ud.set(v, forKey: "appTheme") }
            if let v = d["language"] as? String { ud.set(v, forKey: "appLanguage") }
            if let v = d["preferredCategory"] as? String { ud.set(v, forKey: "preferredCategory") }
        }
    }

    func pushSettings() {
        guard let uid = user?.uid else { return }
        let ud = UserDefaults.standard
        FirestoreService.shared.saveSettings(uid: uid, theme: ud.string(forKey: "appTheme") ?? "system",
                                             language: ud.string(forKey: "appLanguage") ?? "fr",
                                             preferredCategory: ud.string(forKey: "preferredCategory") ?? "")
    }

    private func run(_ work: @escaping () async throws -> Void) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { try await work() }
        catch {
            if (error as NSError).domain == kGIDSignInErrorDomain, (error as NSError).code == GIDSignInError.canceled.rawValue { return }
            errorMessage = message(for: error)
        }
    }

    private func message(for error: Error) -> String {
        let ns = error as NSError
        let debug = " [\(ns.domain) \(ns.code)]"   // à retirer une fois le problème réglé
        guard ns.domain == "FIRAuthErrorDomain" else {
            return (ns.domain == "NutriLife" ? L("err.auth.google") : L("err.generic")) + debug
        }
        switch ns.code {
        case 17004, 17008, 17009, 17011: return L("err.auth.invalid")
        case 17007: return L("err.auth.exists")
        case 17026: return L("err.auth.weak")
        case 17020: return L("err.auth.network")
        case 17010: return L("err.auth.many")
        default: return L("err.generic") + debug
        }
    }
}

extension String { var nonEmpty: String? { isEmpty ? nil : self } }
