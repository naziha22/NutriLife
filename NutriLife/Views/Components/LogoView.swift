import SwiftUI

/// Feuille dessinée en vectoriel (aucune image nécessaire).
struct LeafShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.97))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.03),
                   control1: CGPoint(x: -w * 0.12, y: h * 0.72), control2: CGPoint(x: w * 0.02, y: h * 0.2))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.97),
                   control1: CGPoint(x: w * 0.98, y: h * 0.2), control2: CGPoint(x: w * 1.12, y: h * 0.72))
        p.closeSubpath()
        return p
    }
}

struct LeafVein: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.97))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.28), control: CGPoint(x: w * 0.58, y: h * 0.62))
        return p
    }
}

/// Logo NutriLife animé : le contour de la feuille se dessine, se remplit, puis oscille doucement ;
/// un point orange (fruit/soleil) apparaît avec un effet de ressort.
struct LogoView: View {
    var size: CGFloat = 140
    var onDark = false          // true sur fond vert (splash) : pastille blanche, feuille verte
    var animated = true

    @State private var trim: CGFloat = 0
    @State private var filled = false
    @State private var dot = false
    @State private var sway = false
    @State private var appear = false

    var body: some View {
        let leafW = size * 0.44, leafH = size * 0.56
        let leafColor: Color = onDark ? AppColor.green : .white
        let veinColor: Color = onDark ? .white : AppColor.green

        ZStack {
            Circle()
                .fill(onDark ? AnyShapeStyle(Color.white)
                             : AnyShapeStyle(LinearGradient(colors: [AppColor.green, AppColor.greenDark], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .shadow(color: .black.opacity(0.25), radius: size * 0.08, y: size * 0.04)
                .scaleEffect(appear ? 1 : 0.3)

            ZStack {
                LeafShape().trim(from: 0, to: trim)
                    .stroke(leafColor, style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round, lineJoin: .round))
                    .frame(width: leafW, height: leafH)
                LeafShape().fill(leafColor).frame(width: leafW, height: leafH).opacity(filled ? 1 : 0)
                LeafVein().stroke(veinColor, style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
                    .frame(width: leafW, height: leafH).opacity(filled ? 1 : 0)
            }
            .rotationEffect(.degrees(sway ? 5 : -5), anchor: .bottom)

            Circle().fill(AppColor.accent).frame(width: size * 0.17, height: size * 0.17)
                .offset(x: size * 0.23, y: -size * 0.2).scaleEffect(dot ? 1 : 0)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard animated else { appear = true; trim = 1; filled = true; dot = true; return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appear = true }
            withAnimation(.easeInOut(duration: 0.9).delay(0.3)) { trim = 1 }
            withAnimation(.easeIn(duration: 0.4).delay(1.1)) { filled = true }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.45).delay(1.4)) { dot = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(1.6)) { sway = true }
        }
    }
}

/// Titre dont les lettres apparaissent une à une ("Nutri" en blanc, "Life" en orange).
struct AnimatedTitle: View {
    let text: String
    var highlightFrom = 5
    var fontSize: CGFloat = 38
    var delay: Double = 1.0
    @State private var shown = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { i, ch in
                Text(String(ch))
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(i >= highlightFrom ? AppColor.accent : Color.white)
                    .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 18)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay + Double(i) * 0.06), value: shown)
            }
        }
        .onAppear { shown = true }
    }
}
