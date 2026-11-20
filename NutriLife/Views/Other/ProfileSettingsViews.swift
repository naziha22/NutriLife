import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var favorites: FavoritesViewModel
    @EnvironmentObject var planner: PlannerViewModel
    @EnvironmentObject var recipes: RecipeViewModel
    @AppStorage("preferredCategory") private var preferred = ""
    @State private var showEdit = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Text(String(auth.displayName.prefix(1)).uppercased()).font(.title.bold()).foregroundStyle(.white)
                            .frame(width: 64, height: 64).background(AppColor.green, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(auth.displayName).font(.headline)
                            Text(auth.user?.email ?? "").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { newName = auth.displayName; showEdit = true } label: { Image(systemName: "pencil.circle.fill").font(.title2) }
                    }.padding(.vertical, 6)
                    HStack { stat("\(favorites.items.count)", L("tab.favorites")); stat("\(planner.meals.count)", L("plan.title")) }
                }
                Section(L("profile.preferences")) {
                    Picker(L("profile.preferred"), selection: $preferred) {
                        Text(L("profile.none")).tag("")
                        ForEach(recipes.categories) { Text($0.name).tag($0.name) }
                    }
                }
                Section {
                    NavigationLink { MealHistoryView() } label: { Label(L("profile.history"), systemImage: "clock.arrow.circlepath") }
                    NavigationLink { NutritionDashboardView() } label: { Label(L("profile.nutrition"), systemImage: "chart.pie.fill") }
                    NavigationLink { SettingsView() } label: { Label(L("profile.settings"), systemImage: "gearshape.fill") }
                }
                Section {
                    Button(role: .destructive) { auth.signOut() } label: { Label(L("auth.logout"), systemImage: "rectangle.portrait.and.arrow.right") }
                }
            }
            .navigationTitle(L("profile.title"))
            .onChange(of: preferred) { _, _ in auth.pushSettings() }
            .task { await recipes.loadHome() }
            .alert(L("profile.edit.name"), isPresented: $showEdit) {
                TextField(L("auth.name"), text: $newName)
                Button(L("common.cancel"), role: .cancel) {}
                Button(L("common.save")) { Task { await auth.updateName(newName) } }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack { Text(value).font(.title2.bold()).foregroundStyle(AppColor.green); Text(label).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
    }
}

struct MealHistoryView: View {
    @EnvironmentObject var planner: PlannerViewModel
    @EnvironmentObject var recipes: RecipeViewModel

    private var past: [PlannedMeal] {
        let today = DateKey.string(Calendar.current.startOfDay(for: Date()))
        return planner.meals.filter { $0.date < today }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section(L("profile.history.past")) {
                if past.isEmpty { Text(L("profile.history.empty")).foregroundStyle(.secondary) }
                ForEach(past) { m in
                    HStack(spacing: 12) {
                        RemoteImage(urlString: m.recipe.thumbnail, preview: true).frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading) { Text(m.recipe.name).font(.subheadline); Text("\(m.date) · \(L(m.slot.titleKey))").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            Section(L("home.recent")) {
                ForEach(recipes.recents) { r in
                    HStack(spacing: 12) {
                        RemoteImage(urlString: r.thumbnail, preview: true).frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 10))
                        Text(r.name).font(.subheadline)
                    }
                }
            }
        }.navigationTitle(L("profile.history"))
    }
}

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @AppStorage("appTheme") private var theme = "system"
    @AppStorage("appLanguage") private var language = "fr"
    @AppStorage("notifyDaily") private var notify = false

    var body: some View {
        Form {
            Section(L("set.appearance")) {
                Picker(L("set.theme"), selection: $theme) {
                    Label(L("set.theme.system"), systemImage: "iphone").tag("system")
                    Label(L("set.theme.light"), systemImage: "sun.max").tag("light")
                    Label(L("set.theme.dark"), systemImage: "moon").tag("dark")
                }.pickerStyle(.inline).labelsHidden()
            }
            Section(L("set.language")) {
                Picker(L("set.language"), selection: $language) {
                    Text("Français").tag("fr"); Text("English").tag("en"); Text("العربية").tag("ar")
                }.pickerStyle(.inline).labelsHidden()
            }
            Section(L("set.notifications")) {
                Toggle(L("set.notifications.desc"), isOn: $notify)
            }
            Section(L("set.about")) {
                Text(L("set.ads.note")).font(.footnote).foregroundStyle(.secondary)
                LabeledContent(L("set.version"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }
        }
        .navigationTitle(L("set.title"))
        .onChange(of: theme) { _, _ in auth.pushSettings() }
        .onChange(of: language) { _, _ in auth.pushSettings() }
        .onChange(of: notify) { _, on in Task { if !(await NotificationManager.setDailyReminder(on)) { notify = false } } }
    }
}
