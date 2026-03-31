import SwiftUI

struct CreateSparkView: View {
    @State private var title = "Evening cricket near HAL grounds"
    @State private var category: SparkCategory = .sports
    @State private var location = "HAL Turf, Indiranagar"
    @State private var time = "Today, 6:30 PM"
    @State private var spots = 3.0
    @State private var radius = 8.0

    var body: some View {
        ZStack {
            SparkBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Create spark")
                        .font(SparkTheme.Typography.displayLarge)
                        .padding(.horizontal, 4)

                    preview
                    form
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
        }
        .navigationBarHidden(true)
    }

    private var preview: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Live preview")
                    .font(SparkTheme.Typography.label)
                    .foregroundStyle(SparkTheme.Colors.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    Text(category.rawValue.uppercased())
                        .font(SparkTheme.Typography.label)
                        .foregroundStyle(category.color)
                    Text(title)
                        .font(SparkTheme.Typography.displaySmall)
                    Text("\(time)  |  \(location)")
                        .font(SparkTheme.Typography.body)
                        .foregroundStyle(SparkTheme.Colors.secondaryText)
                }

                HStack(spacing: 10) {
                    previewPill("\(Int(spots)) spots")
                    previewPill("\(Int(radius)) km radius")
                }
            }
        }
    }

    private var form: some View {
        VStack(spacing: 16) {
            inputCard("Spark title") {
                TextField("", text: $title, prompt: Text("What are you planning?"))
            }

            inputCard("Category") {
                Picker("Category", selection: $category) {
                    ForEach(SparkCategory.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            inputCard("Start time") {
                TextField("", text: $time, prompt: Text("Today, 6:30 PM"))
            }

            inputCard("Location") {
                TextField("", text: $location, prompt: Text("Venue or pickup point"))
            }

            inputCard("Spots open") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Seats")
                        Spacer()
                        Text("\(Int(spots))")
                            .foregroundStyle(SparkTheme.Colors.primaryText)
                    }
                    Slider(value: $spots, in: 1...12, step: 1)
                        .tint(SparkTheme.Colors.accent)
                }
            }

            inputCard("Visibility radius") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Match radius")
                        Spacer()
                        Text("\(Int(radius)) km")
                            .foregroundStyle(SparkTheme.Colors.primaryText)
                    }
                    Slider(value: $radius, in: 1...20, step: 1)
                        .tint(SparkTheme.Colors.accent)
                }
            }

            Button {
            } label: {
                Text("Launch spark")
                    .font(SparkTheme.Typography.body)
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 174 / 255, blue: 84 / 255), SparkTheme.Colors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func inputCard<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(label.uppercased())
                    .font(SparkTheme.Typography.label)
                    .foregroundStyle(SparkTheme.Colors.secondaryText)
                content()
                    .font(SparkTheme.Typography.body)
                    .textFieldStyle(.plain)
            }
        }
    }

    private func previewPill(_ value: String) -> some View {
        Text(value)
            .font(SparkTheme.Typography.bodySmall)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white.opacity(0.06), in: Capsule())
    }
}
