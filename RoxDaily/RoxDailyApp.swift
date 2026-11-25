import SwiftUI

@main
struct RoxDailyApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            Group {
                if store.profile == nil {
                    OnboardingView()
                } else {
                    RootView()
                }
            }
            .environmentObject(store)
            .preferredColorScheme(.light)
            .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    /// `-tab N` on the command line opens a given tab; used for automated screenshots.
    @State private var tab = UserDefaults.standard.integer(forKey: "tab")

    var body: some View {
        TabView(selection: $tab) {
            TodayView().tabItem { Label("Today", systemImage: "house.fill") }.tag(0)
            PlanView().tabItem { Label("Plan", systemImage: "calendar") }.tag(1)
            NewsView().tabItem { Label("News", systemImage: "newspaper.fill") }.tag(2)
            RaceView().tabItem { Label("Race", systemImage: "flag.checkered") }.tag(3)
            StatsView().tabItem { Label("Progress", systemImage: "chart.bar.fill") }.tag(4)
        }
    }
}
