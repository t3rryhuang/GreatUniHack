import SwiftUI

/// Teen borrowing sandbox: try a loan before ever taking one. Works offline.
struct SandboxCard: View {
    @Environment(AppModel.self) private var model
    @Bindable var viewModel: SandboxViewModel

    var body: some View {
        let outcome = viewModel.outcome(model: model)
        NovaCard {
            SectionHeader(title: "Borrowing sandbox", systemImage: "testtube.2") {
                if model.readinessProgress.sandboxDone {
                    Label("Done", systemImage: "checkmark.circle.fill").font(.novaCaption.weight(.semibold)).foregroundStyle(NovaColor.success)
                }
            }
            Text("Borrow \(viewModel.amount.gbpWhole), repay over \(viewModel.months) month\(viewModel.months == 1 ? "" : "s")")
                .font(.novaSection).foregroundStyle(NovaColor.heading)
            Text("Practice only. Nothing is borrowed.").font(.novaCaption).foregroundStyle(NovaColor.muted)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Amount: \(viewModel.amount.gbpWhole)").font(.novaCallout).foregroundStyle(NovaColor.heading)
                Slider(value: $viewModel.amount, in: 20...500, step: 10) { Text("Amount") }
                    .accessibilityValue(viewModel.amount.gbpWhole)
            }
            Stepper(value: $viewModel.months, in: 1...12) {
                Text("Repay over \(viewModel.months) month\(viewModel.months == 1 ? "" : "s")").font(.novaCallout)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Example interest: \(Int(viewModel.apr))% APR").font(.novaCallout).foregroundStyle(NovaColor.heading)
                Slider(value: $viewModel.apr, in: 0...40, step: 1) { Text("Example interest") }
                    .accessibilityValue("\(Int(viewModel.apr)) percent APR")
                Text("0% is like a family loan. Real credit usually costs more.").font(.novaCaption).foregroundStyle(NovaColor.muted)
            }

            HStack(spacing: Spacing.sm) {
                figure("Each month", viewModel.monthly.gbp)
                figure("Total repaid", viewModel.totalRepaid.gbp)
                figure("Interest", viewModel.interest.gbp)
            }

            Text("What happens to Reliability").overline()
            HStack(spacing: Spacing.sm) {
                outcomeTile(title: "All on time", points: outcome.allOnTime, change: outcome.allOnTime - outcome.now, good: true)
                outcomeTile(title: "One missed", points: outcome.oneMissed, change: outcome.oneMissed - outcome.now, good: false)
            }
            Text("Your Readiness Score changes by the same amount. Missed payments on real credit can stay on a credit file for years.")
                .font(.novaCaption).foregroundStyle(NovaColor.body)
                .fixedSize(horizontal: false, vertical: true)

            Button(model.readinessProgress.sandboxDone ? "Completed, nice work" : "I've finished the sandbox") {
                Task { await viewModel.finish(model: model) }
            }
            .buttonStyle(.novaPrimary)
            .disabled(model.readinessProgress.sandboxDone)
        }
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.novaCaption).foregroundStyle(NovaColor.body)
            Text(value).font(.novaHeadline).foregroundStyle(NovaColor.heading).monospacedDigit()
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(NovaColor.tonal, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func outcomeTile(title: String, points: Int, change: Int, good: Bool) -> some View {
        let tint = good ? NovaColor.success : NovaColor.error
        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            Label(title, systemImage: good ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.novaCallout.weight(.semibold)).foregroundStyle(tint)
            Text("\(points) / 200").font(.novaSection).foregroundStyle(NovaColor.heading).monospacedDigit()
            Text("\(change >= 0 ? "+" : "")\(change) points").font(.novaCaption).foregroundStyle(NovaColor.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(good ? NovaColor.successTint : NovaColor.errorTint, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): Reliability \(points) of 200, \(change >= 0 ? "up" : "down") \(abs(change)) points")
    }
}
