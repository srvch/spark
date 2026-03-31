import SwiftUI

struct DiscoveryView: View {
    @State private var selectedCategory: SparkCategory = .sports
    @State private var radius: Double = 8
    @Namespace private var categoryAnimation

    var filteredEvents: [SparkEvent] {
        SparkEvent.sample.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ZStack {
            SparkBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    hero
                    controlBar
                    liveFeed
                    categoryStory
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SPARK")
                    .font(SparkTheme.Typography.label)
                    .foregroundStyle(SparkTheme.Colors.secondaryText)
                Text("Nearby plans, alive right now.")
                    .font(SparkTheme.Typography.displayLarge)
                    .foregroundStyle(SparkTheme.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 8) {
                Text("Indiranagar")
                    .font(SparkTheme.Typography.body)
                Text("8 km live radius")
                    .font(SparkTheme.Typography.bodySmall)
                    .foregroundStyle(SparkTheme.Colors.secondaryText)
            }
        }
    }

    private var hero: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 18) {
                Text("Find a game, ride, show, or side quest before the moment disappears.")
                    .font(SparkTheme.Typography.displaySmall)
                    .foregroundStyle(SparkTheme.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Spark is built for tiny plans with real intent: a cricket game in two hours, an airport cab split, a comedy room, or a last-minute house hunt.")
                    .font(SparkTheme.Typography.body)
                    .foregroundStyle(SparkTheme.Colors.secondaryText)

                RadarHero()

                HStack(spacing: 10) {
                    MetricPill(value: "2h", title: "Shelf life")
                    MetricPill(value: "\(Int(radius)) km", title: "Radius")
                    MetricPill(value: "\(filteredEvents.count)", title: "Live now")
                }
            }
        }
    }

    private var controlBar: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Match settings")
                        .font(SparkTheme.Typography.title)
                    Spacer()
                    Text("\(Int(radius)) km")
                        .font(SparkTheme.Typography.body)
                        .foregroundStyle(SparkTheme.Colors.primaryText)
                }

                Slider(value: $radius, in: 1...20, step: 1)
                    .tint(SparkTheme.Colors.accent)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SparkCategory.allCases) { category in
                            categoryChip(category)
                        }
                    }
                }
            }
        }
    }

    private func categoryChip(_ category: SparkCategory) -> some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                Text(category.rawValue)
            }
            .font(SparkTheme.Typography.bodySmall)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                ZStack {
                    if selectedCategory == category {
                        Capsule()
                            .fill(category.color.opacity(0.18))
                            .matchedGeometryEffect(id: "category-chip", in: categoryAnimation)
                    } else {
                        Capsule()
                            .fill(.white.opacity(0.05))
                    }
                }
            }
            .overlay {
                Capsule()
                    .stroke(.white.opacity(selectedCategory == category ? 0 : 0.08), lineWidth: 1)
            }
            .foregroundStyle(selectedCategory == category ? category.color : SparkTheme.Colors.primaryText)
        }
        .buttonStyle(.plain)
    }

    private var liveFeed: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Live sparks around you")
                .font(SparkTheme.Typography.title)
                .padding(.horizontal, 6)

            ForEach(filteredEvents) { event in
                SparkRow(event: event)
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            }
        }
    }

    private var categoryStory: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Why this category works")
                    .font(SparkTheme.Typography.title)

                Text(categoryDescription(for: selectedCategory))
                    .font(SparkTheme.Typography.body)
                    .foregroundStyle(SparkTheme.Colors.secondaryText)

                HStack(spacing: 12) {
                    Image(systemName: selectedCategory.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(selectedCategory.color)
                        .frame(width: 52, height: 52)
                        .background(selectedCategory.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCategory.rawValue)
                            .font(SparkTheme.Typography.body)
                        Text("Optimized for high-intent, low-friction plans.")
                            .font(SparkTheme.Typography.bodySmall)
                            .foregroundStyle(SparkTheme.Colors.secondaryText)
                    }

                    Spacer()
                }
            }
        }
    }

    private func categoryDescription(for category: SparkCategory) -> String {
        switch category {
        case .sports:
            "Sports sparks shine when the group size is clear, the start time is close, and the location is easy to reach."
        case .transit:
            "Transit sparks turn awkward solo travel into efficient, trusted coordination for airports, stations, and long rides."
        case .fun:
            "Fun sparks are perfect for game zones, cafes, and lightweight social plans that feel too small for group chats."
        case .culture:
            "Culture sparks make it easy to fill one extra seat, find company for a show, or rally a tiny crowd for an open mic."
        case .life:
            "Life sparks cover practical moments like house hunting, study loops, errands, and other social tasks people rarely productize."
        }
    }
}

private struct MetricPill: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(SparkTheme.Typography.title)
            Text(title.uppercased())
                .font(SparkTheme.Typography.label)
                .foregroundStyle(SparkTheme.Colors.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SparkRow: View {
    let event: SparkEvent
    @State private var isPressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed.toggle()
            }
        } label: {
            GlassPanel {
                HStack(alignment: .top, spacing: 14) {
                    Circle()
                        .fill(event.category.color.opacity(0.18))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Image(systemName: event.category.icon)
                                .foregroundStyle(event.category.color)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.category.rawValue.uppercased())
                            .font(SparkTheme.Typography.label)
                            .foregroundStyle(event.category.color)
                        Text(event.title)
                            .font(SparkTheme.Typography.title)
                            .foregroundStyle(SparkTheme.Colors.primaryText)
                        Text("\(event.subtitle)  |  \(event.location)")
                            .font(SparkTheme.Typography.bodySmall)
                            .foregroundStyle(SparkTheme.Colors.secondaryText)
                        Text("\(event.spotsLeft) spots left  |  \(event.distance)")
                            .font(SparkTheme.Typography.bodySmall)
                            .foregroundStyle(SparkTheme.Colors.secondaryText)
                    }

                    Spacer(minLength: 10)

                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(SparkTheme.Colors.secondaryText)
                }
            }
            .scaleEffect(isPressed ? 0.985 : 1)
        }
        .buttonStyle(.plain)
    }
}
