import SwiftUI

@main
struct NovaApp: App {
    @State private var model = AppModel(services: .mock())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(NovaColor.action)
        }
    }
}
