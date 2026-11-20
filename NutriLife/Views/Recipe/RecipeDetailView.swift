import SwiftUI

struct RecipeDetailView: View {
    let summary: RecipeSummary
    @EnvironmentObject var favorites: FavoritesViewModel
    @EnvironmentObject var recipesVM: RecipeViewModel
    @EnvironmentObject var ads: AdsManager
    @State private var recipe: Recipe?
    @State private var error: String?
    @State private var servings = 4
    @State private var showPlan = false
    private let baseServings = 4.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RemoteImage(urlString: summary.thumbnail).frame(height: 280).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous)).padding(.horizontal)
                Text(summary.name).font(.system(size: 26, weight: .bold, design: .rounded)).padding(.horizontal)

                if let recipe {
                    details(recipe).transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let error {
                    ErrorView(message: error) { Task { await load() } }
                } else { LoadingView() }
            }.padding(.vertical).animation(.spring(response: 0.5, dampingFraction: 0.85), value: recipe)
        }
        .background(AppColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: URL(string: "https://www.themealdb.com/meal/\(summary.id)")!, subject: Text(summary.name),
                          message: Text(summary.name)) { Image(systemName: "square.and.arrow.up") }
                Button { showPlan = true } label: { Image(systemName: "calendar.badge.plus") }.disabled(recipe == nil)
                let fav = favorites.isFavorite(summary.id)
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { favorites.toggle(recipe?.summary ?? summary) } } label: {
                    Image(systemName: fav ? "heart.fill" : "heart").foregroundStyle(fav ? .red : AppColor.green).symbolEffect(.bounce, value: fav)
                }
            }
        }
        .sheet(isPresented: $showPlan) { if let recipe { AddToPlanSheet(recipe: recipe.summary).presentationDetents([.medium]) } }
        .task { await load() }
        .onDisappear { ads.recipeScreenClosed() }   // interstitiel : moment naturel, fréquence limitée
    }

    @ViewBuilder private func details(_ r: Recipe) -> some View {
        HStack(spacing: 8) {
            if let c = r.category { pill(c, "leaf.fill") }
            if let a = r.area { pill(a, "globe") }
            ForEach(r.tags.prefix(2), id: \.self) { pill($0, "tag") }
        }.padding(.horizontal)

        // Les durées de préparation et portions ne sont pas fournies par TheMealDB : rien n'est inventé.
        VStack(alignment: .leading, spacing: 10) {
            Label(L("detail.nutrition"), systemImage: "chart.bar.doc.horizontal").font(.headline)
            Text(L("detail.nutrition.unavailable")).font(.footnote).foregroundStyle(.secondary)
        }.padding().frame(maxWidth: .infinity, alignment: .leading).cardStyle().padding(.horizontal)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("detail.ingredients")).font(.title3.bold())
                Spacer()
                Stepper(value: $servings, in: 1...20) {
                    Label("\(servings) \(L("detail.servings"))", systemImage: "person.2.fill").font(.subheadline.weight(.semibold))
                }.frame(maxWidth: 190)
            }
            Text(L("detail.servings.note")).font(.caption).foregroundStyle(.secondary)
            ForEach(r.ingredients) { ing in
                HStack(spacing: 12) {
                    RemoteImage(urlString: "https://www.themealdb.com/images/ingredients/\(ing.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ing.name)-small.png")
                        .frame(width: 36, height: 36).clipShape(Circle())
                    Text(ing.name).font(.subheadline)
                    Spacer()
                    Text(MeasureParser.format(MeasureParser.parse(ing.measure), factor: Double(servings) / baseServings))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppColor.accent)
                        .contentTransition(.numericText()).animation(.default, value: servings)
                }
                Divider()
            }
        }.padding().cardStyle().padding(.horizontal)

        VStack(alignment: .leading, spacing: 14) {
            Text(L("detail.instructions")).font(.title3.bold())
            ForEach(Array(r.steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)").font(.footnote.bold()).foregroundStyle(.white).frame(width: 26, height: 26).background(AppColor.green, in: Circle())
                    Text(step).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let yt = r.youtube, let url = URL(string: yt) {
                Link(destination: url) { Label(L("detail.video"), systemImage: "play.rectangle.fill").font(.subheadline.weight(.semibold)) }
                    .foregroundStyle(AppColor.accent)
            }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).cardStyle().padding(.horizontal)
    }

    private func pill(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon).font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
            .background(AppColor.greenSoft, in: Capsule()).foregroundStyle(AppColor.green)
    }

    private func load() async {
        error = nil
        do {
            if let r = try await RecipeAPIService.shared.lookup(id: summary.id) {
                recipe = r; recipesVM.markViewed(r.summary)
            } else { error = L("detail.notfound") }
        } catch { if !isCancel(error) { self.error = error.localizedDescription } }
    }
}

struct AddToPlanSheet: View {
    let recipe: RecipeSummary
    @EnvironmentObject var planner: PlannerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var slot: MealSlot = .lunch

    var body: some View {
        VStack(spacing: 18) {
            Text(L("plan.add")).font(.title3.bold()).padding(.top, 20)
            Text(recipe.name).font(.subheadline).foregroundStyle(.secondary)
            DatePicker(L("plan.date"), selection: $date, displayedComponents: .date).environment(\.locale, appLocale())
            Picker(L("plan.slot"), selection: $slot) {
                ForEach(MealSlot.allCases) { Text(L($0.titleKey)).tag($0) }
            }.pickerStyle(.segmented)
            CustomButton(title: L("plan.confirm"), icon: "checkmark") {
                planner.set(recipe, on: date, slot: slot); dismiss()
            }
            Spacer()
        }.padding(.horizontal, 24)
    }
}
