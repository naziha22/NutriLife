# NutriLife — iOS (SwiftUI · MVVM · Firebase · TheMealDB · AdMob)

Application de découverte de recettes et de planification des repas.
iOS 17+, Xcode 15+, Swift 5.9, 100 % SwiftUI (UIKit uniquement pour l'enveloppe `BannerView` d'AdMob).

> ⚠️ Ce code a été écrit sans Xcode (non compilé ici). Au premier build, de petits ajustements de syntaxe/version de SDK peuvent être nécessaires.

## 1. Générer le projet Xcode
Le dépôt contient `project.yml` (XcodeGen) qui déclare les dépendances Swift Package Manager (Firebase Auth/Firestore, GoogleSignIn 8.x, Google Mobile Ads 11.x).
```bash
brew install xcodegen
cd NutriLife && xcodegen generate
open NutriLife.xcodeproj
```
Sans XcodeGen : créez un projet iOS App SwiftUI « NutriLife », glissez le dossier `NutriLife/` (sources + `Resources/*.lproj`), remplacez son Info.plist par `Config/Info.plist`, puis ajoutez via *File ▸ Add Package Dependencies* : `firebase-ios-sdk` (FirebaseAuth, FirebaseFirestore), `GoogleSignIn-iOS` (GoogleSignIn), `swift-package-manager-google-mobile-ads` (GoogleMobileAds, version 11.x), et ajoutez `-ObjC` à *Other Linker Flags*.

## 2. Firebase Console
1. Créez un projet Firebase, ajoutez une app iOS avec le Bundle ID `com.nutrilife.app` (ou le vôtre, à modifier aussi dans `project.yml`).
2. Téléchargez `GoogleService-Info.plist` et placez-le dans `NutriLife/` (cible NutriLife cochée). Ne le versionnez pas.
3. *Authentication ▸ Sign-in method* : activez **E-mail/Mot de passe** et **Google** (renseignez l'e-mail d'assistance).
4. *Firestore Database* : créez la base (mode production), puis *Rules* : collez `firestore.rules` et publiez.
5. Collections créées automatiquement : `users`, `favorites`, `mealPlans`, `shoppingLists`, `userSettings` — chaque document personnel porte `userId` = UID du propriétaire.

## 3. Google Sign-In (Google Cloud Console)
- Le client OAuth iOS est créé automatiquement par Firebase (*APIs & Services ▸ Credentials*). Vérifiez que son Bundle ID correspond à votre app.
- Ouvrez `GoogleService-Info.plist`, copiez la valeur `REVERSED_CLIENT_ID` et collez-la dans `Config/Info.plist` à la place de `com.googleusercontent.apps.REMPLACER_PAR_REVERSED_CLIENT_ID` (URL scheme). Régénérez avec `xcodegen generate`.
- *OAuth consent screen* : renseignez le nom de l'app et ajoutez votre compte comme utilisateur test si l'app n'est pas publiée.

## 4. Publicités (identifiants de TEST Google uniquement)
- App ID (Info.plist) : `ca-app-pub-3940256099942544~1458002511`
- Banner (accueil) : `ca-app-pub-3940256099942544/2934735716` · Interstitial : `ca-app-pub-3940256099942544/4411468910`
- `AdsManager` : interstitiel affiché au plus toutes les 3 fiches recette fermées et jamais plus d'une fois / 90 s.

## 5. Architecture
```
App/        NutriLifeApp (config, thème, langue, RTL), RootView, MainTabView
Core/       Theme, Utilities (L(), Validator, NetworkMonitor, ErrorCenter)
Models/     Recipe, Category, RecipeSummary (Codable), planning, courses, parsing des quantités
Services/   RecipeAPIService (URLSession+async/await), FirestoreService, AdsManager, NutritionService, NotificationManager
ViewModels/ Auth, Recipe/Search, Favorites, Planner, Shopping
Views/      12 écrans + composants (RecipeCard, CategoryCard, SearchBar, CustomButton, LoadingView, EmptyStateView, ErrorView, CustomTabBar)
Resources/  Localizable.strings fr / en / ar (RTL activé pour l'arabe)
```
Écrans : Splash, Login, Register, Home, Search, RecipeDetail, Favorites, MealPlanner, ShoppingList, NutritionDashboard, Profile, Settings (+ historique, sélecteur de recette, ajout au planning).

## 6. Limites assumées (honnêteté des données)
- **TheMealDB ne fournit ni calories/macros, ni temps de préparation, ni nombre de portions.** Rien n'est inventé : l'UI affiche « non disponible ». Le tableau de bord montre des statistiques réelles (repas par jour/catégorie/créneau). Pour de vraies valeurs, implémentez `NutritionProviding` (USDA FoodData Central, Edamam…).
- Le filtre « temps de préparation » n'est donc pas proposé (donnée absente de l'API).
- Les portions sont un multiplicateur (référence 4) appliqué aux quantités.
- Bonus inclus : fonctionnement hors ligne (cache Firestore + récents locaux) et notifications locales.
