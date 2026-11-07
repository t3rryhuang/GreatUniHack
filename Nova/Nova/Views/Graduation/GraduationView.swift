import SwiftUI

/// Teen mode: countdown to 18 and the checklist for a first credit product.
struct GraduationView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = GraduationViewModel()

    var body: some View {
        let items = viewModel.items(model: model)
        let done = items.filter(\.1).count
        NovaScreen {
            NovaBrandBand {
                Label("Road to 18", systemImage: "graduationcap.fill").font(.novaHeadline)
                if let days = viewModel.daysToEighteen(model: model), let birthday = model.eighteenthBirthday {
                    Text("\(days) days").font(.novaHero).monospacedDigit()
                    Text("until your 18th birthday on \(birthday.formatted(.dateTime.day().month(.wide).year()))")
                        .font(.novaCallout).foregroundStyle(.white.opacity(0.85))
                } else {
                    Text("Add your date of birth to see your countdown.").font(.novaTitle)
                }
                ProbabilityBar(value: Double(done) / Double(items.count), tint: .white)
                    .accessibilityHidden(false)
                    .accessibilityLabel("Checklist")
                    .accessibilityValue("\(done) of \(items.count) done")
                Text("\(done) of \(items.count) done").font(.novaCaption).foregroundStyle(.white.opacity(0.85))
            }

            NovaCard {
                SectionHeader(title: "Your checklist", systemImage: "checklist")
                ForEach(items, id: \.0) { item, isDone in
                    ChecklistRow(item: item, isDone: isDone) {
                        if item.isManual { Task { await model.setVotingChecked(!isDone) } }
                    }
                }
            }

            NavigationLink { ReadinessReportView() } label: {
                RowLink(title: "Readiness Report", subtitle: "Preview a one-page summary you can choose to share", symbol: "doc.richtext.fill")
            }
            .buttonStyle(.plain)

            NovaNotice(kind: .info, title: "When you turn 18",
                       message: "Nova moves you to the full app on your birthday. Your score, streak and history come with you.")
            ReadinessDisclaimer()
        }
        .navigationTitle("Graduation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChecklistRow: View {
    let item: GraduationItem
    let isDone: Bool
    let toggle: () -> Void

    var body: some View {
        if item.isManual {
            Button(action: toggle) { content }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityValue(isDone ? "Done" : "Not done")
                .accessibilityAddTraits(.isButton)
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityValue(isDone ? "Done" : "Not done yet")
        }
    }

    private var content: some View {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? NovaColor.success : NovaColor.muted)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    Text(item.detail).font(.novaCaption).foregroundStyle(NovaColor.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if item.isManual {
                        Text(isDone ? "Tap to untick" : "Tap when done").font(.novaCaption.weight(.semibold)).foregroundStyle(NovaColor.action)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
    }
}

/// One-page Readiness Report with an explicit consent toggle before sharing.
struct ReadinessReportView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = GraduationViewModel()

    var body: some View {
        NovaScreen {
            if let data = viewModel.reportData(model: model) {
                ReadinessReportPage(data: data)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(NovaColor.hairline))

                NovaCard {
                    Toggle(isOn: $viewModel.consent) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I agree to share this report").font(.novaHeadline).foregroundStyle(NovaColor.heading)
                            Text("You choose who sees it. Nova never sends it for you.").font(.novaCaption).foregroundStyle(NovaColor.body)
                        }
                    }
                    .tint(NovaColor.action)
                    if viewModel.consent, let url = viewModel.pdfURL {
                        ShareLink(item: url) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.novaPrimary)
                    } else {
                        Button {} label: { Label("Share PDF", systemImage: "square.and.arrow.up") }
                            .buttonStyle(.novaPrimary)
                            .disabled(true)
                            .accessibilityHint("Turn on the consent switch first")
                    }
                }
                .onChange(of: viewModel.consent) { _, on in if on { viewModel.renderPDF(data) } }
            } else {
                LoadingCard(label: "Preparing your report…")
            }
        }
        .navigationTitle("Readiness Report")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.markReportPreviewed() }
    }
}

/// The report itself. Also rendered to PDF, so it doesn't read the environment model.
struct ReadinessReportPage: View {
    let data: ReadinessReportData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Readiness Report").font(.title2.weight(.semibold)).foregroundStyle(NovaColor.brandText)
                    Text("\(data.name) · \(data.date.formatted(date: .long, time: .omitted))").font(.footnote).foregroundStyle(NovaColor.body)
                }
                Spacer()
                NatWestMark(size: 40)
            }
            Divider()
            HStack(spacing: 16) {
                ReadinessCharacter(rank: data.rank, size: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(data.score)").font(.system(size: 44, weight: .semibold)).foregroundStyle(NovaColor.heading).monospacedDigit()
                    Text("of 1000 · \(data.rank.title)").font(.headline).foregroundStyle(NovaColor.action)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                row("Months of on-time payments", "\(data.onTimeMonths)")
                row("On-time payments", "\(data.onTimePayments)")
                row("Longest quest streak", "\(data.longestStreak) days")
                row("Savings buffer", String(format: "%.1f weeks of spending", data.bufferWeeks))
                row("Loans fully repaid", "\(data.loansRepaid)")
            }
            Divider()
            ForEach(data.stats) { stat in
                HStack {
                    Text("\(stat.stat.title) (\(stat.stat.creditFactor.lowercased()))").font(.footnote).foregroundStyle(NovaColor.heading)
                    Spacer()
                    Text("\(stat.points) / 200").font(.footnote.weight(.semibold)).foregroundStyle(NovaColor.heading).monospacedDigit()
                }
            }
            Divider()
            Text("\(ReadinessScore.disclaimer) It isn't shared with credit reference agencies and doesn't change a credit file.")
                .font(.caption).foregroundStyle(NovaColor.body)
                .fixedSize(horizontal: false, vertical: true)
            Text("Made with NatWest Nova, a hackathon concept.").font(.caption2).foregroundStyle(NovaColor.muted)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).font(.subheadline).foregroundStyle(NovaColor.body)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(NovaColor.heading)
        }
    }
}
