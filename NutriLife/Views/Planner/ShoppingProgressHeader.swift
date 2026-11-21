import SwiftUI

/// En-tête animé de la liste de courses : barre de progression des achats + confettis quand tout est acheté.
/// Données réelles uniquement (articles cochés / total).
struct ShoppingProgressHeader: View {
    let done: Int
    let total: Int

    @State private var progress: CGFloat = 0
    @State private var celebrate = false

    private var target: CGFloat { total == 0 ? 0 : CGFloat(done) / CGFloat(total) }
    private var allDone: Bool { total > 0 && done == total }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: allDone ? "checkmark.seal.fill" : "cart.fill")
                    .font(.title2).foregroundStyle(allDone ? AppColor.green : AppColor.accent)
                    .symbolEffect(.bounce, value: done)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(done) / \(total)").font(.system(size: 24, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: Double(done)))
                        .animation(.easeOut(duration: 0.5), value: done)
                    Text(L("shop.done")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int((target * 100).rounded())) %").font(.headline).foregroundStyle(AppColor.green)
                    .contentTransition(.numericText(value: Double(done)))
                    .animation(.easeOut(duration: 0.5), value: done)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColor.greenSoft)
                    Capsule()
                        .fill(LinearGradient(colors: [AppColor.accent, AppColor.green], startPoint: .leading, endPoint: .trailing))
                        .frame(width: progress > 0 ? max(g.size.width * progress, 14) : 0)
                }
            }.frame(height: 14)
        }
        .padding(16)
        .background(AppColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { if celebrate { ConfettiView().allowsHitTesting(false) } }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        .onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.15)) { progress = target } }
        .onChange(of: done) { old, new in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { progress = target }
            if allDone && new > old {
                celebrate = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { celebrate = false }
            }
        }
        .onChange(of: total) { _, _ in withAnimation(.easeOut(duration: 0.5)) { progress = target } }
    }
}

/// Pluie de confettis (formes simples, couleurs de la charte).
struct ConfettiView: View {
    struct Piece: Identifiable {
        let id = UUID()
        let x = CGFloat.random(in: 0.05...0.95)
        let size = CGFloat.random(in: 6...11)
        let delay = Double.random(in: 0...0.5)
        let spin = Double.random(in: 180...540)
        let color: Color = [AppColor.accent, AppColor.green, Color.yellow, Color.pink, Color.blue].randomElement() ?? AppColor.accent
        let round = Bool.random()
    }
    @State private var pieces = (0..<28).map { _ in Piece() }
    @State private var fall = false

    var body: some View {
        GeometryReader { g in
            ForEach(pieces) { p in
                Group {
                    if p.round { Circle().fill(p.color) } else { Rectangle().fill(p.color) }
                }
                .frame(width: p.size, height: p.size * (p.round ? 1 : 1.6))
                .rotationEffect(.degrees(fall ? p.spin : 0))
                .position(x: g.size.width * p.x, y: fall ? g.size.height + 20 : -12)
                .opacity(fall ? 0 : 1)
                .animation(.easeIn(duration: 1.5).delay(p.delay), value: fall)
            }
        }
        .onAppear { fall = true }
    }
}
