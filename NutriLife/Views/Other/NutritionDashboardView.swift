import SwiftUI
import Charts

struct NutritionDashboardView: View {
    @EnvironmentObject var planner: PlannerViewModel

    struct Stat: Identifiable { let id: String; let name: String; let count: Int }

    private var perDay: [Stat] {
        planner.weekDays.map { d in
            Stat(id: DateKey.string(d), name: d.formatted(Date.FormatStyle().weekday(.abbreviated).locale(appLocale())), count: planner.meals(on: d).count)
        }
    }
    private var byCategory: [Stat] {
        Dictionary(grouping: planner.weekMeals, by: { $0.recipe.category ?? L("nut.other") })
            .map { Stat(id: $0.key, name: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }
    }
    private var bySlot: [Stat] {
        MealSlot.allCases.map { s in Stat(id: s.rawValue, name: L(s.titleKey), count: planner.weekMeals.filter { $0.slot == s }.count) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DashboardHero(planned: planner.weekMeals.count)
                // Les valeurs nutritionnelles ne sont jamais inventées : TheMealDB n'en fournit pas.
                VStack(alignment: .leading, spacing: 12) {
                    Label(L("nut.unavailable"), systemImage: "info.circle.fill").font(.headline).foregroundStyle(AppColor.accent)
                    Text(L("nut.unavailable.note")).font(.footnote).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        tile(L("nut.calories"), "flame.fill", .orange); tile(L("nut.protein"), "fish.fill", .red)
                        tile(L("nut.carbs"), "leaf.fill", .green); tile(L("nut.fat"), "drop.fill", .yellow)
                    }
                }.padding().frame(maxWidth: .infinity, alignment: .leading).cardStyle()

                card(title: L("nut.meals.week") + " · \(planner.weekMeals.count)") {
                    if planner.weekMeals.isEmpty { Text(L("nut.nodata")).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80) }
                    else {
                        Chart(perDay) { BarMark(x: .value("d", $0.name), y: .value("n", $0.count)).foregroundStyle(AppColor.green).cornerRadius(6) }
                            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }.frame(height: 160)
                    }
                }
                if !byCategory.isEmpty {
                    card(title: L("nut.bycategory")) {
                        Chart(byCategory) { SectorMark(angle: .value("n", $0.count), innerRadius: .ratio(0.6), angularInset: 2).foregroundStyle(by: .value("c", $0.name)).cornerRadius(4) }
                            .frame(height: 200)
                    }
                    card(title: L("nut.byslot")) {
                        Chart(bySlot) { BarMark(x: .value("n", $0.count), y: .value("s", $0.name)).foregroundStyle(AppColor.accent).cornerRadius(6) }.frame(height: 130)
                    }
                }
            }.padding().animation(.easeInOut, value: planner.meals)
        }
        .background(AppColor.background)
        .navigationTitle(L("nut.title")).navigationBarTitleDisplayMode(.inline)
    }

    private func tile(_ title: String, _ icon: String, _ color: Color) -> some View {
        HStack { Image(systemName: icon).foregroundStyle(color); VStack(alignment: .leading) { Text(title).font(.caption); Text("—").font(.title3.bold()) }; Spacer() }
            .padding(12).background(AppColor.background, in: RoundedRectangle(cornerRadius: 14)).opacity(0.7)
    }

    private func card<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline); content() }
            .padding().frame(maxWidth: .infinity, alignment: .leading).cardStyle()
    }
}
