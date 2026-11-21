import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct NutriLifeApp: App {
    @AppStorage("appTheme") private var theme = "system"
    @AppStorage("appLanguage") private var language = "fr"
    @StateObject private var auth: AuthViewModel
    @StateObject private var recipes = RecipeViewModel()
    @StateObject private var favorites = FavoritesViewModel()
    @StateObject private var planner = PlannerViewModel()
    @StateObject private var shopping = ShoppingViewModel()
    @StateObject private var network = NetworkMonitor()
    @StateObject private var router = Router()
    @StateObject private var ads = AdsManager.shared

    init() {
        FirebaseApp.configure()   // nécessite GoogleService-Info.plist
        _auth = StateObject(wrappedValue: AuthViewModel())
    }

    private var colorScheme: ColorScheme? {
        switch theme { case "light": return .light; case "dark": return .dark; default: return nil }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth).environmentObject(recipes).environmentObject(favorites)
                .environmentObject(planner).environmentObject(shopping).environmentObject(network)
                .environmentObject(router).environmentObject(ads)
                .preferredColorScheme(colorScheme)
                .environment(\.locale, Locale(identifier: language))
                .environment(\.layoutDirection, language == "ar" ? .rightToLeft : .leftToRight)
                .tint(AppColor.green)
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var favorites: FavoritesViewModel
    @EnvironmentObject var planner: PlannerViewModel
    @EnvironmentObject var shopping: ShoppingViewModel
    @EnvironmentObject var ads: AdsManager
    @ObservedObject private var errors = ErrorCenter.shared
    @AppStorage("appLanguage") private var language = "fr"
    @State private var showSplash = true

    private var phase: Int { showSplash || !auth.isReady ? 0 : (auth.user == nil ? 1 : 2) }

    var body: some View {
        ZStack {
            switch phase {
            case 0: SplashView().transition(.opacity)
            case 1: AuthFlowView().id(language).transition(.opacity)
            default: MainTabView().id(language).transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: phase)
        .overlay(alignment: .top) {
            if let m = errors.message {
                Label(m, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.white)
                    .padding(12).background(Color.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
                    .padding().transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: errors.message)
        .task {
            ads.start()
            try? await Task.sleep(for: .seconds(3.0))
            showSplash = false
        }
        .onChange(of: auth.user?.uid, initial: true) { _, uid in
            if let uid {
                favorites.start(uid: uid); planner.start(uid: uid); shopping.start(uid: uid)
                Task { await auth.syncSettings() }
            } else {
                favorites.stop(); planner.stop(); shopping.stop()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var router: Router
    var body: some View {
        ZStack {
            switch router.tab {
            case .home: HomeView()
            case .favorites: FavoritesView()
            case .planner: MealPlannerView()
            case .shopping: ShoppingListView()
            case .profile: ProfileView()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: router.tab)
        .safeAreaInset(edge: .bottom) { CustomTabBar(selection: $router.tab) }
    }
}
