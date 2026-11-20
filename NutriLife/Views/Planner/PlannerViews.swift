import SwiftUI

struct MealPlannerView: View {
    @EnvironmentObject var planner: PlannerViewModel
    @State private var pickerTarget: SlotTarget?

    struct SlotTarget: Identifiable { let id = UUID(); let date: Date; let slot: MealSlot }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Button { withAnimation { planner.shiftWeek(-1) } } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(rangeTitle).font(.headline)
                        Spacer()
                        Button { withAnimation { planner.shiftWeek(1) } } label: { Image(systemName: "chevron.right") }
                    }.padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) { ForEach(planner.weekDays, id: \.self) { dayChip($0) } }.padding(.horizontal)
                    }

                    VStack(spacing: 12) {
                        ForEach(MealSlot.allCases) { slot in slotCard(slot) }
                    }.padding(.horizontal).id(planner.selectedDate)
                    .transition(.opacity)
                }.padding(.vertical)
            }
            .background(AppColor.background)
            .navigationTitle(L("plan.title"))
            .navigationDestination(for: RecipeSummary.self) { RecipeDetailView(summary: $0) }
            .navigationDestination(for: String.self) { _ in NutritionDashboardView() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(L("plan.today")) { withAnimation { planner.weekOffset = 0; planner.selectedDate = Date() } } }
                ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: "nutrition") { Image(systemName: "chart.pie.fill") } }
            }
            .sheet(item: $pickerTarget) { t in
                RecipePickerView { picked in planner.set(picked, on: t.date, slot: t.slot) }
            }
        }
    }

    private var rangeTitle: String {
        guard let f = planner.weekDays.first, let l = planner.weekDays.last else { return "" }
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(appLocale())
        return "\(f.formatted(style)) – \(l.formatted(style))"
    }

    private func dayChip(_ d: Date) -> some View {
        let selected = Calendar.current.isDate(d, inSameDayAs: planner.selectedDate)
        let count = planner.meals(on: d).count
        return Button { withAnimation(.spring(response: 0.3)) { planner.selectedDate = d } } label: {
            VStack(spacing: 6) {
                Text(d.formatted(Date.FormatStyle().weekday(.abbreviated).locale(appLocale()))).font(.caption)
                Text(d.formatted(Date.FormatStyle().day().locale(appLocale()))).font(.title3.bold())
                Circle().fill(count > 0 ? (selected ? Color.white : AppColor.accent) : .clear).frame(width: 6, height: 6)
            }
            .frame(width: 52).padding(.vertical, 12)
            .foregroundStyle(selected ? .white : .primary)
            .background(selected ? AppColor.green : AppColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(selected ? 1.05 : 1)
        }.buttonStyle(.plain)
    }

    private func slotCard(_ slot: MealSlot) -> some View {
        let meal = planner.meal(on: planner.selectedDate, slot: slot)
        return VStack(alignment: .leading, spacing: 10) {
            Label(L(slot.titleKey), systemImage: slot.icon).font(.subheadline.weight(.semibold)).foregroundStyle(AppColor.green)
            if let meal {
                HStack(spacing: 12) {
                    NavigationLink(value: meal.recipe) {
                        HStack(spacing: 12) {
                            RemoteImage(urlString: meal.recipe.thumbnail, preview: true).frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 14))
                            Text(meal.recipe.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading).foregroundStyle(.primary)
                        }
                    }.buttonStyle(.plain)
                    Spacer()
                    Menu {
                        Button { pickerTarget = SlotTarget(date: planner.selectedDate, slot: slot) } label: { Label(L("plan.change"), systemImage: "arrow.triangle.2.circlepath") }
                        Button(role: .destructive) { withAnimation { planner.remove(meal) } } label: { Label(L("plan.remove"), systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                }
            } else {
                Button { pickerTarget = SlotTarget(date: planner.selectedDate, slot: slot) } label: {
                    Label(L("plan.add"), systemImage: "plus.circle.fill").font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .foregroundStyle(AppColor.accent).background(AppColor.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain)
            }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).cardStyle()
    }
}

/// Sélecteur de recette : favoris ou recherche TheMealDB.
struct RecipePickerView: View {
    let onPick: (RecipeSummary) -> Void
    @EnvironmentObject var favorites: FavoritesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [RecipeSummary] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                SearchBar(text: $query, placeholder: L("search.placeholder.name")).padding(.horizontal)
                List {
                    if query.trimmed.isEmpty {
                        Section(L("plan.pick.favorites")) {
                            if favorites.items.isEmpty { Text(L("fav.empty.title")).foregroundStyle(.secondary) }
                            ForEach(favorites.items) { row($0) }
                        }
                    } else if isLoading { LoadingView().listRowBackground(Color.clear) }
                    else if let error { Text(error).foregroundStyle(.red) }
                    else if results.isEmpty { Text(L("search.empty.msg")).foregroundStyle(.secondary) }
                    else { ForEach(results) { row($0) } }
                }.listStyle(.insetGrouped)
            }
            .background(AppColor.background)
            .navigationTitle(L("plan.pick.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(L("common.cancel")) { dismiss() } } }
            .task(id: query) {
                let q = query.trimmed
                guard !q.isEmpty else { results = []; return }
                try? await Task.sleep(for: .milliseconds(350)); if Task.isCancelled { return }
                isLoading = true; error = nil
                do { results = try await RecipeAPIService.shared.search(name: q).map(\.summary) }
                catch { if isCancel(error) { return }; self.error = error.localizedDescription }
                isLoading = false
            }
        }
    }

    private func row(_ r: RecipeSummary) -> some View {
        Button { onPick(r); dismiss() } label: {
            HStack(spacing: 12) {
                RemoteImage(urlString: r.thumbnail, preview: true).frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10))
                Text(r.name).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "plus.circle").foregroundStyle(AppColor.accent)
            }
        }
    }
}

struct ShoppingListView: View {
    @EnvironmentObject var shopping: ShoppingViewModel
    @EnvironmentObject var planner: PlannerViewModel
    @State private var showAdd = false
    @State private var name = ""
    @State private var qty = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CustomButton(title: shopping.isGenerating ? L("shop.generating") : L("shop.generate"), icon: "wand.and.stars", style: .accent, isLoading: shopping.isGenerating) {
                        Task { await shopping.generate(from: planner.meals) }
                    }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    if let e = shopping.error { Text(e).font(.footnote).foregroundStyle(.red) }
                }
                if shopping.items.isEmpty {
                    EmptyStateView(icon: "cart", title: L("shop.empty.title"), message: L("shop.empty.msg")).listRowBackground(Color.clear)
                }
                if !shopping.remaining.isEmpty {
                    Section(String(format: L("shop.todo"), shopping.remaining.count)) {
                        ForEach(shopping.remaining) { row($0) }.onDelete { idx in idx.map { shopping.remaining[$0] }.forEach(shopping.remove) }
                    }
                }
                if !shopping.purchased.isEmpty {
                    Section {
                        ForEach(shopping.purchased) { row($0) }.onDelete { idx in idx.map { shopping.purchased[$0] }.forEach(shopping.remove) }
                    } header: {
                        HStack { Text(L("shop.done")); Spacer(); Button(L("shop.clear")) { withAnimation { shopping.clearPurchased() } }.font(.caption) }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(AppColor.background)
            .animation(.default, value: shopping.items)
            .navigationTitle(L("shop.title"))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus.circle.fill") } } }
            .alert(L("shop.add.title"), isPresented: $showAdd) {
                TextField(L("shop.add.name"), text: $name)
                TextField(L("shop.add.qty"), text: $qty)
                Button(L("common.cancel"), role: .cancel) { name = ""; qty = "" }
                Button(L("common.add")) { shopping.addManual(name: name, quantity: qty); name = ""; qty = "" }
            }
        }
    }

    private func row(_ item: ShoppingItem) -> some View {
        Button { withAnimation(.spring(response: 0.3)) { shopping.toggle(item) } } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle").font(.title3)
                    .foregroundStyle(item.isChecked ? AppColor.green : .secondary).symbolEffect(.bounce, value: item.isChecked)
                VStack(alignment: .leading) {
                    Text(item.name).strikethrough(item.isChecked).foregroundStyle(item.isChecked ? .secondary : .primary)
                    if item.isManual { Text(L("shop.manual")).font(.caption2).foregroundStyle(AppColor.accent) }
                }
                Spacer()
                Text(item.quantityText).font(.subheadline).foregroundStyle(.secondary)
            }
        }.buttonStyle(.plain)
    }
}
