import SwiftUI
import GoogleMobileAds

/// Identifiants de TEST officiels Google (https://developers.google.com/admob/ios/test-ads). Ne jamais utiliser de vrais IDs en développement.
enum AdIDs {
    static let banner = "ca-app-pub-3940256099942544/2934735716"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
}

/// Centralise les publicités : bannière (accueil) et interstitiel (affiché peu souvent, après la consultation de plusieurs recettes).
@MainActor
final class AdsManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = AdsManager()
    private var interstitial: InterstitialAd?
    private var recipesClosed = 0
    private var lastShown = Date.distantPast
    private let everyNRecipes = 3
    private let minInterval: TimeInterval = 90

    func start() {
        MobileAds.shared.start(completionHandler: nil)
        Task { await loadInterstitial() }
    }

    func loadInterstitial() async {
        do {
            let ad = try await InterstitialAd.load(with: AdIDs.interstitial, request: Request())
            ad.fullScreenContentDelegate = self
            interstitial = ad
        } catch { print("Interstitial load failed:", error.localizedDescription) }
    }

    /// Moment naturel : l'utilisateur quitte une fiche recette. Fréquence limitée pour rester non intrusif.
    func recipeScreenClosed() {
        recipesClosed += 1
        guard recipesClosed % everyNRecipes == 0, Date().timeIntervalSince(lastShown) > minInterval else { return }
        showInterstitial()
    }

    func showInterstitial() {
        guard let ad = interstitial, let root = UIApplication.shared.topViewController else { return }
        lastShown = Date()
        ad.present(fromRootViewController: root)
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.interstitial = nil
            await self.loadInterstitial()
        }
    }
}

struct BannerAdView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: AdSizeBanner)
        view.adUnitID = AdIDs.banner
        view.rootViewController = UIApplication.shared.topViewController
        view.load(Request())
        return view
    }
    func updateUIView(_ uiView: BannerView, context: Context) {}
}
