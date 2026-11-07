import SwiftUI

/// Switches between launch, sign-in, onboarding and the main tabs.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            switch model.phase {
            case .launching:
                LaunchView()
            case .signedOut:
                LoginView()
            case .onboarding:
                OnboardingView()
            case .ready:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.phase)
        .task { await model.start() }
        .sheet(isPresented: $model.showUpgrade) { UpgradeView() }
        .sheet(isPresented: $model.showChat) { ChatView() }
        .sheet(isPresented: $model.showAddTransaction) { AddTransactionView() }
        .fullScreenCover(isPresented: $model.showBriefing) { BriefingView() }
        .sheet(item: $model.lockedFeature) { feature in
            LockedFeatureSheet(feature: feature)
                .presentationDetents([.medium])
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct LaunchView: View {
    var body: some View {
        ZStack {
            NovaColor.brandBand.ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                NatWestMark(size: 88)
                Text("Nova")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white)
                ProgressView().tint(.white)
            }
        }
    }
}

struct MainTabView: View {
    // Launch with `-NovaTab 4` to open on a given tab (handy for demos and screenshots).
    @State private var tab = UserDefaults.standard.integer(forKey: "NovaTab")

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }.tag(0)
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar") }.tag(1)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }.tag(2)
            ArenaListView()
                .tabItem { Label("Arena", systemImage: "trophy") }.tag(3)
            SimulatorView()
                .tabItem { Label("Simulator", systemImage: "slider.horizontal.3") }.tag(4)
        }
        // Profile is reached from the avatar button on every tab (see `profileToolbar`),
        // keeping the tab bar at Apple's recommended maximum of five tabs.
    }
}
