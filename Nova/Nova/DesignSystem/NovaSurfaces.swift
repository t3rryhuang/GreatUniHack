import SwiftUI

/// A flat card: surface colour plus a 1pt hairline, no shadow
/// (NatWest section 9 and the Apple doc both keep chrome flat).
struct NovaCard<Content: View>: View {
    var padding: CGFloat = Spacing.md
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(NovaColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(NovaColor.hairline, lineWidth: 1)
        )
    }
}

/// A purple brand band: the "dark tile" from the Apple doc, in NatWest champion purple.
struct NovaBrandBand<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .foregroundStyle(.white)
        .background(NovaColor.brandBand, in: RoundedRectangle(cornerRadius: Radius.promo, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}

/// Card header: semibold title with an optional SF Symbol and trailing accessory.
struct SectionHeader<Accessory: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(NovaColor.action)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.novaHeadline)
                .foregroundStyle(NovaColor.brandText)
            Spacer(minLength: Spacing.xs)
            accessory
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(title: String, systemImage: String? = nil) {
        self.init(title: title, systemImage: systemImage) { EmptyView() }
    }
}

/// Notification box: 8pt status-coloured leading bar (NatWest 12.5).
struct NovaNotice: View {
    enum Kind { case info, success, warning, error }

    let kind: Kind
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                Text(message).font(.novaCallout).foregroundStyle(NovaColor.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .padding(.leading, Spacing.xs)
        .background(NovaColor.card)
        .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 8) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(NovaColor.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch kind {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch kind {
        case .info: NovaColor.info
        case .success: NovaColor.success
        case .warning: NovaColor.warning
        case .error: NovaColor.error
        }
    }
}

/// Page background for scroll views.
struct NovaScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    content
                    Color.clear.frame(height: 1).id("nova-bottom")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            #if DEBUG
            .task {
                // -NovaWalkthrough: scroll each screen slowly to the bottom for screen recordings.
                guard ProcessInfo.processInfo.arguments.contains("-NovaWalkthrough") else { return }
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.easeInOut(duration: 3)) { proxy.scrollTo("nova-bottom", anchor: .bottom) }
            }
            #endif
        }
        .background(NovaColor.page.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }
}

/// Text field styled as a NatWest input: 48pt tall, 8pt corners, 1pt border.
struct NovaFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.novaBody)
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: 48)
            .background(NovaColor.card, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(NovaColor.muted, lineWidth: 1)
            )
    }
}

extension View {
    func novaField() -> some View { modifier(NovaFieldStyle()) }
}
