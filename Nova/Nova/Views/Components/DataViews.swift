import SwiftUI

/// Ring progress (used for runway and accuracy). Ported from RunwayRing and AccuracyRing.
struct RingView<Center: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 14
    var tint: Color = NovaColor.action
    @ViewBuilder var center: Center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(NovaColor.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0.001, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: progress)
            center
        }
    }
}

/// Horizontal probability bar (NatWest progress bar: purple fill on a lilac track).
struct ProbabilityBar: View {
    let value: Double
    var tint: Color = NovaColor.action

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(NovaColor.track)
                Capsule().fill(tint).frame(width: proxy.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// Row for one predicted spend: icon, title, probability bar, amount.
struct PredictionRow: View {
    let item: PredictionItem

    var body: some View {
        HStack(spacing: Spacing.sm) {
            CategoryIcon(category: item.category)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    Spacer()
                    Text(item.amount.gbp).font(.novaHeadline).foregroundStyle(NovaColor.heading).monospacedDigit()
                }
                ProbabilityBar(value: item.probability, tint: item.category.color)
                HStack {
                    Text("\(item.probability.percent) likely").font(.novaCaption).foregroundStyle(NovaColor.body)
                    Spacer()
                    if !item.agreedBy.isEmpty {
                        Text("\(item.agreedBy.count) of 3 models agree")
                            .font(.novaCaption)
                            .foregroundStyle(NovaColor.muted)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.probability.percent) likely, about \(item.amount.gbp)")
    }
}

/// Empty state shown when there's no transaction data yet.
struct NoDataView: View {
    @Environment(AppModel.self) private var model
    var title = "No transactions yet"
    var message = "Import a statement or use demo data to see your predictions."

    var body: some View {
        NovaCard(padding: Spacing.lg) {
            VStack(spacing: Spacing.md) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(NovaColor.action)
                    .accessibilityHidden(true)
                Text(title).font(.novaSection).foregroundStyle(NovaColor.brandText)
                Text(message).font(.novaBody).foregroundStyle(NovaColor.body).multilineTextAlignment(.center)
                Button("Add transactions") { model.showAddTransaction = true }
                    .buttonStyle(.novaPrimary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Small loading card used while a section waits for the service layer.
struct LoadingCard: View {
    var label = "Analysing your spending…"

    var body: some View {
        NovaCard {
            HStack(spacing: Spacing.sm) {
                ProgressView()
                Text(label).font(.novaCallout).foregroundStyle(NovaColor.body)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        }
    }
}

/// Lock badge and upsell row for Pro-only content.
struct ProLockedCard: View {
    @Environment(AppModel.self) private var model
    let feature: ProFeature

    var body: some View {
        NovaCard {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(NovaColor.action)
                    .frame(width: 40, height: 40)
                    .background(NovaColor.lilac, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock \(feature.title.lowercased())").font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    Text(feature.detail).font(.novaCaption).foregroundStyle(NovaColor.body)
                }
                Spacer(minLength: 0)
            }
            Button("Upgrade to Pro") { model.showUpgrade = true }
                .buttonStyle(.novaSecondary)
        }
    }
}

/// Sheet shown when a free user taps a Pro feature. Ported from LockedFeatureModal.
struct LockedFeatureSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let feature: ProFeature

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(NovaColor.action)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.xs) {
                Text(feature.title).font(.novaTitle).foregroundStyle(NovaColor.brandText)
                Text(feature.detail).font(.novaBody).foregroundStyle(NovaColor.body).multilineTextAlignment(.center)
                Text("Part of Nova Pro. Try it free for 7 days, then £1.99 a month.")
                    .font(.novaCallout).foregroundStyle(NovaColor.muted).multilineTextAlignment(.center)
            }
            VStack(spacing: Spacing.sm) {
                Button("Start free trial") {
                    dismiss()
                    // Wait for this sheet to close before presenting the next one.
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        model.showUpgrade = true
                    }
                }
                .buttonStyle(.novaPrimary)
                Button("Not now") { dismiss() }
                    .buttonStyle(.novaSecondary)
            }
        }
        .padding(Spacing.lg)
        .frame(maxHeight: .infinity)
        .background(NovaColor.card)
    }
}
