import SwiftUI
import UIKit

/// Caches generated what-if illustrations by theme, in memory and on disk.
/// Similar questions share a theme (for example "coffee-at-home"), so after the
/// first one the picture appears instantly, even after relaunching the app.
actor IllustrationCache {
    static let shared = IllustrationCache()

    private let memory = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private let directory: URL = {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NovaIllustrations", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    init() { memory.countLimit = 60 }

    /// Returns the cached image straight away if there is one (no network).
    func cached(theme: String) -> UIImage? {
        if let image = memory.object(forKey: theme as NSString) { return image }
        let file = directory.appendingPathComponent("\(theme).webp")
        guard let data = try? Data(contentsOf: file), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: theme as NSString)
        return image
    }

    func image(theme: String, url: URL) async -> UIImage? {
        if let image = cached(theme: theme) { return image }
        if let task = inFlight[theme] { return await task.value }
        let file = directory.appendingPathComponent("\(theme).webp")
        let task = Task<UIImage?, Never> {
            var request = URLRequest(url: url)
            request.timeoutInterval = 45
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let image = UIImage(data: data) else { return nil }
            try? data.write(to: file, options: .atomic)
            return image
        }
        inFlight[theme] = task
        let image = await task.value
        inFlight[theme] = nil
        if let image { memory.setObject(image, forKey: theme as NSString) }
        return image
    }
}

/// The illustration at the top of a what-if card, with a soft placeholder while it's generated.
struct WhatIfIllustration: View {
    let theme: String
    let url: URL?
    let icon: String
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [NovaColor.lilac, NovaColor.tonal], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(NovaColor.action.opacity(0.6))
                        .symbolEffect(.pulse, isActive: url != nil && !failed)
                    if url != nil && !failed {
                        Text("Drawing your scenario…").font(.novaCaption).foregroundStyle(NovaColor.body)
                    }
                }
            }
        }
        .aspectRatio(3 / 2, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .accessibilityHidden(true)
        .task(id: theme) {
            guard let url else { return }
            if let hit = await IllustrationCache.shared.cached(theme: theme) {
                image = hit
                return
            }
            let loaded = await IllustrationCache.shared.image(theme: theme, url: url)
            withAnimation(.easeOut(duration: 0.35)) {
                image = loaded
                failed = loaded == nil
            }
        }
    }
}
