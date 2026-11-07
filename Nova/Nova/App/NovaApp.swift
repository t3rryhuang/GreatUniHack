import SwiftUI

@main
struct NovaApp: App {
    @State private var model = AppModel(services: BackendConfig.baseURL.map { .live(baseURL: $0) } ?? .mock())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(NovaColor.action)
        }
    }
}
