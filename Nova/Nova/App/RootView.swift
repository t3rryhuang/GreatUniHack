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
        .sheet(isPresented: $model.showEighteenWelcome) { EighteenWelcomeView() }
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

/// Shown once on the 18th birthday, when Teen mode ends.
struct EighteenWelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NovaScreen {
            VStack(spacing: Spacing.md) {
                if let readiness = model.readiness {
                    ReadinessCharacter(rank: readiness.score.rank, size: 120)
                } else {
                    Image(systemName: "party.popper.fill").font(.system(size: 64)).foregroundStyle(NovaColor.action)
                }
                Text("Happy 18th, \(model.user?.firstName ?? "there")!").font(.novaTitle).foregroundStyle(NovaColor.brandText)
                Text("Welcome to the full Nova. Your Readiness Score, streak and history come with you.")
                    .font(.novaBody).foregroundStyle(NovaColor.body).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.xl)
            NovaCard {
                SectionHeader(title: "What's new for you", systemImage: "sparkles")
                Label("Arenas can now have stakes, if you want them", systemImage: "trophy.fill").font(.novaCallout)
                Label("Ask Nova can talk about credit products", systemImage: "bubble.left.fill").font(.novaCallout)
                Label("Your Readiness Report is ready to share", systemImage: "doc.richtext.fill").font(.novaCallout)
            }
            NovaNotice(kind: .info, title: "Your credit file starts now",
                       message: "\(ReadinessScore.disclaimer) Nova doesn't create or change a credit file. Registering to vote and paying bills on time are good first steps.")
            Button("Let's go") { dismiss() }.buttonStyle(.novaPrimary)
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
    #if DEBUG
    @State private var debugScreen: DebugScreen?
    #endif

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar") }
                .tag(1)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(2)
            ArenaListView()
                .tabItem { Label("Arena", systemImage: "trophy") }
                .tag(3)
            SimulatorView()
                .tabItem { Label("Simulator", systemImage: "slider.horizontal.3") }
                .tag(4)
        }
        #if DEBUG
        .task {
            guard let requested = DebugScreen.requested else { return }
            UserDefaults.standard.set(true, forKey: "nova.arenaIntroSeen")
            if let index = requested.tab { tab = index } else {
                try? await Task.sleep(for: .milliseconds(600))
                debugScreen = requested
            }
        }
        .sheet(item: $debugScreen) { screen in
            if screen == .chat { screen.destination } else { NavigationStack { screen.destination } }
        }
        #endif
        // Profile is reached from the avatar button on every tab (see `profileToolbar`),
        // keeping the tab bar at Apple's recommended maximum of five tabs.
    }
}
