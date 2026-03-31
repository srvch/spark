import SwiftUI

struct RadarHero: View {
    @State private var animatePulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            SparkTheme.Colors.backgroundElevated,
                            SparkTheme.Colors.background
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(SparkTheme.Colors.stroke, lineWidth: 1)
                }

            TimelineView(.animation) { _ in
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radii: [CGFloat] = [56, 110, 168]

                    for radius in radii {
                        let rect = CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        context.stroke(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(0.08)),
                            lineWidth: 1
                        )
                    }
                }
            }

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(SparkTheme.Colors.accent.opacity(0.22), lineWidth: 1.2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(animatePulse ? 4.3 : 1)
                    .opacity(animatePulse ? 0 : 1)
                    .animation(
                        .easeOut(duration: 3.2)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.8),
                        value: animatePulse
                    )
            }

            Circle()
                .fill(SparkTheme.Colors.accent)
                .frame(width: 18, height: 18)
                .shadow(color: SparkTheme.Colors.accent.opacity(0.8), radius: 24)

            HeroPin(
                category: "Sports",
                title: "Evening cricket",
                detail: "6:30 PM, 2 spots",
                tint: SparkTheme.Colors.success
            )
            .offset(x: -110, y: -90)

            HeroPin(
                category: "Transit",
                title: "Airport split",
                detail: "In 45 min",
                tint: SparkTheme.Colors.transit
            )
            .offset(x: 95, y: -50)

            HeroPin(
                category: "Culture",
                title: "Open mic drop-in",
                detail: "Tonight",
                tint: SparkTheme.Colors.culture
            )
            .offset(x: 104, y: 104)

            HeroPin(
                category: "Life",
                title: "House hunt",
                detail: "Sunday morning",
                tint: SparkTheme.Colors.life
            )
            .offset(x: -112, y: 126)
        }
        .frame(height: 360)
        .onAppear {
            animatePulse = true
        }
    }
}

private struct HeroPin: View {
    let category: String
    let title: String
    let detail: String
    let tint: Color
    @State private var drift = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.uppercased())
                .font(SparkTheme.Typography.label)
                .foregroundStyle(tint)
            Text(title)
                .font(SparkTheme.Typography.body)
                .foregroundStyle(SparkTheme.Colors.primaryText)
            Text(detail)
                .font(SparkTheme.Typography.bodySmall)
                .foregroundStyle(SparkTheme.Colors.secondaryText)
        }
        .padding(14)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .offset(y: drift ? -5 : 5)
        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: drift)
        .onAppear {
            drift = true
        }
    }
}
