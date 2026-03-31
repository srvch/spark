import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DiscoveryView()
            }
            .tabItem {
                Label("Discover", systemImage: "location.viewfinder")
            }

            NavigationStack {
                CreateSparkView()
            }
            .tabItem {
                Label("Create", systemImage: "plus.app.fill")
            }

            NavigationStack {
                InboxPlaceholderView()
            }
            .tabItem {
                Label("Inbox", systemImage: "bubble.left.and.bubble.right.fill")
            }
        }
        .tint(SparkTheme.Colors.accent)
    }
}

private struct InboxPlaceholderView: View {
    var body: some View {
        ZStack {
            SparkTheme.Colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text("Inbox")
                    .font(SparkTheme.Typography.displaySmall)
                Text("Matches, confirmations, and live spark chats would land here.")
                    .font(SparkTheme.Typography.body)
                    .foregroundStyle(SparkTheme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
        }
    }
}
