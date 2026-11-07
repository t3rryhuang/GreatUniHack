import SwiftUI

/// The NatWest symbol (from Images/og-logo-nw.png) in a rounded square.
struct NatWestMark: View {
    var size: CGFloat = 44

    var body: some View {
        Image("NatWestMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityLabel("NatWest")
    }
}

/// Full NatWest logo. In Dark Mode the purple wordmark would disappear,
/// so the symbol is shown with a white wordmark instead.
struct NatWestLogo: View {
    var height: CGFloat = 44
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                HStack(spacing: height * 0.25) {
                    NatWestMark(size: height)
                    Text("NatWest")
                        .font(.system(size: height * 0.62, weight: .bold))
                        .foregroundStyle(.white)
                }
            } else {
                Image("NatWestLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: height * 1.25)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("NatWest")
    }
}

/// "Nova by NatWest" lockup used on sign-in and onboarding.
struct NovaLockup: View {
    var body: some View {
        VStack(spacing: Spacing.xs) {
            NatWestMark(size: 72)
            Text("Nova")
                .font(.system(.largeTitle).weight(.semibold))
                .foregroundStyle(NovaColor.brandText)
            Text("by NatWest")
                .font(.novaCallout)
                .foregroundStyle(NovaColor.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nova by NatWest")
    }
}

/// Circle with initials, used for arena members and the profile button.
struct AvatarView: View {
    let initials: String
    var size: CGFloat = 40
    var highlighted = false

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(highlighted ? NovaColor.onAction : NovaColor.action)
            .frame(width: size, height: size)
            .background(highlighted ? NovaColor.action : NovaColor.lilac, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Category symbol in a tinted circle.
struct CategoryIcon: View {
    let category: SpendingCategory
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(category.color.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }
}

/// Adds the profile button to the top-right of a tab's navigation bar.
struct ProfileToolbar: ViewModifier {
    @Environment(AppModel.self) private var model
    @State private var showProfile = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        AvatarView(initials: initials, size: 34)
                    }
                    .accessibilityLabel("Profile")
                }
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack { ProfileView() }
            }
    }

    private var initials: String {
        let name = model.user?.name ?? "?"
        return name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

extension View {
    func profileToolbar() -> some View { modifier(ProfileToolbar()) }
}
