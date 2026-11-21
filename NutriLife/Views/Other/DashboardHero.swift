import SwiftUI

/// Bandeau animé du tableau de bord : anneau de progression des repas planifiés cette semaine
/// (21 créneaux = 7 jours × 3 repas), point orange en orbite et feuilles flottantes.
/// Données réelles uniquement : aucune valeur nutritionnelle inventée.
/// Dépend de `LeafShape` (défini dans LogoView.swift).
struct DashboardHero: View {
    let planned: Int
    var total = 21

    @State private var progress: CGFloat = 0
    @State private var float = false
    @State private var orbit = false

    private let xs: [CGFloat] = [0.60, 0.82, 0.93, 0.72]
    private let ys: [CGFloat] = [0.22, 0.72, 0.18, 0.90]

    private var target: CGFloat { CGFloat(min(planned, total)) / CGFloat(max(total, 1)) }
    private var percent: Int { Int((target * 100).rounded()) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [AppColor.green, AppColor.greenDark], startPoint: .topLeading, endPoint: .bottomTrailing))
            floatingLeaves
            HStack(spacing: 22) {
                ring
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("nut.meals.week")).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.85))
                    Text("\(percent) %").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(percent)))
                        .animation(.easeOut(duration: 0.6), value: percent)
                }
                Spacer(minLength: 0)
            }.padding(22)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: AppColor.green.opacity(0.3), radius: 14, y: 8)
        .onAppear {
            withAnimation(.easeOut(duration: 1.3).delay(0.2)) { progress = target }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { orbit = true }
            float = true
        }
        .onChange(of: planned) { _, _ in withAnimation(.easeOut(duration: 1)) { progress = target } }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: 12)
            Circle().trim(from: 0, to: progress)
                .stroke(AppColor.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().fill(.white).frame(width: 9, height: 9).offset(y: -60)
                .rotationEffect(.degrees(orbit ? 360 : 0))
            VStack(spacing: 0) {
                Text("\(planned)").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(planned)))
                    .animation(.easeOut(duration: 0.6), value: planned)
                Text("/ \(total)").font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: 120, height: 120)
    }

    private var floatingLeaves: some View {
        GeometryReader { g in
            ForEach(0..<4, id: \.self) { i in
                LeafShape()
                    .fill(Color.white.opacity(0.10 + Double(i) * 0.02))
                    .frame(width: 34 + CGFloat(i) * 10, height: 44 + CGFloat(i) * 12)
                    .rotationEffect(.degrees(float ? Double(20 + i * 25) : Double(-20 - i * 15)))
                    .position(x: g.size.width * xs[i], y: g.size.height * ys[i] + (float ? -8 : 8))
                    .animation(.easeInOut(duration: 2.5 + Double(i) * 0.6).repeatForever(autoreverses: true), value: float)
            }
        }
    }
}
