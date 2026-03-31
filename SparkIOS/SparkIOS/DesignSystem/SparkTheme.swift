import SwiftUI

enum SparkTheme {
    enum Colors {
        static let background = Color(red: 8 / 255, green: 15 / 255, blue: 27 / 255)
        static let backgroundElevated = Color(red: 15 / 255, green: 26 / 255, blue: 43 / 255)
        static let panel = Color.white.opacity(0.07)
        static let panelStrong = Color.white.opacity(0.12)
        static let stroke = Color.white.opacity(0.08)
        static let accent = Color(red: 1.0, green: 123 / 255, blue: 69 / 255)
        static let accentSoft = Color(red: 1.0, green: 123 / 255, blue: 69 / 255).opacity(0.18)
        static let success = Color(red: 116 / 255, green: 240 / 255, blue: 197 / 255)
        static let primaryText = Color(red: 244 / 255, green: 241 / 255, blue: 232 / 255)
        static let secondaryText = Color(red: 158 / 255, green: 168 / 255, blue: 186 / 255)
        static let transit = Color(red: 144 / 255, green: 194 / 255, blue: 255 / 255)
        static let fun = Color(red: 255 / 255, green: 215 / 255, blue: 133 / 255)
        static let culture = Color(red: 255 / 255, green: 177 / 255, blue: 142 / 255)
        static let life = Color(red: 214 / 255, green: 179 / 255, blue: 255 / 255)
    }

    enum Typography {
        static let displayLarge = Font.system(size: 40, weight: .bold, design: .rounded)
        static let displaySmall = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 16, weight: .medium, design: .rounded)
        static let bodySmall = Font.system(size: 13, weight: .medium, design: .rounded)
        static let label = Font.system(size: 12, weight: .semibold, design: .rounded)
    }

    enum Radius {
        static let panel: CGFloat = 28
        static let chip: CGFloat = 18
    }
}

struct SparkBackground: View {
    var body: some View {
        ZStack {
            SparkTheme.Colors.background

            RadialGradient(
                colors: [SparkTheme.Colors.accentSoft, .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 280
            )

            RadialGradient(
                colors: [SparkTheme.Colors.success.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 260
            )

            GridPattern()
                .opacity(0.24)
        }
        .ignoresSafeArea()
    }
}

private struct GridPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 36
            var path = Path()

            stride(from: 0, through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            stride(from: 0, through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
        }
    }
}

struct GlassPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: SparkTheme.Radius.panel, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SparkTheme.Radius.panel, style: .continuous)
                    .stroke(SparkTheme.Colors.stroke, lineWidth: 1)
            }
    }
}
