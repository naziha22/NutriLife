import SwiftUI
import GoogleMobileAds

/// Identifiants de TEST officiels Google. Ne jamais utiliser de vrais IDs en développement.
enum AdIDs {
    static let banner = "ca-app-pub-3940256099942544/2934735716"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
}

/// Centralise les publicités : bannière (accueil) et interstitiel (affiché peu souvent).
@MainActor
final class AdsManager: NSObject, ObservableObject, GADFullScreenContentDelegate {
    static let shared = AdsManager()
    private var interstitial: GADInterstitialAd?
    private var recipesClosed = 0
    private var lastShown = Date.distantPast
    private let everyNRecipes = 3
    private let minInterval: TimeInterval = 90

    func start() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        Task { await loadInterstitial() }
    }

    func loadInterstitial() async {
        do {
            let ad = try await GADInterstitialAd.load(withAdUnitID: AdIDs.interstitial, request: GADRequest())
            ad.fullScreenContentDelegate = self
            interstitial = ad
        } catch { print("Interstitial load failed:", error.localizedDescription) }
    }

    /// Moment naturel : l'utilisateur quitte une fiche recette. Fréquence limitée.
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

    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            self.interstitial = nil
            await self.loadInterstitial()
        }
    }
}

struct BannerAdView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let view = GADBannerView(adSize: GADAdSizeBanner)
        view.adUnitID = AdIDs.banner
        view.rootViewController = UIApplication.shared.topViewController
        view.load(GADRequest())
        return view
    }
    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}