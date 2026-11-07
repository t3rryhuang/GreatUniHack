import SwiftUI

/// Connect flow: welcome, choose bank, choose data source, then connecting.
/// Ported from onboarding.tsx with the bank list changed to NatWest Group and UK banks.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = OnboardingViewModel()
    @State private var showImporter = false

    var body: some View {
        NovaScreen {
            StepIndicator(current: viewModel.step.rawValue, total: OnboardingViewModel.Step.allCases.count)
                .padding(.top, Spacing.md)

            switch viewModel.step {
            case .welcome: welcome
            case .age: ageStep
            case .bank: bankStep
            case .data: dataStep
            case .connecting: connecting
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.step)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: TransactionImporter.allowedTypes) { result in
            if case .success(let url) = result {
                Task { await viewModel.importFile(at: url, model: model) }
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            NovaLockup().frame(maxWidth: .infinity).padding(.vertical, Spacing.lg)
            Text("Welcome\(model.user.map { ", \($0.firstName)" } ?? "")")
                .font(.novaTitle).foregroundStyle(NovaColor.brandText)
            feature("sparkles", "Daily predictions", "See what you're likely to spend today, based on your habits and the Manchester weather.")
            feature("chart.line.uptrend.xyaxis", "Long-term insights", "Know how long your savings would last and where your money goes.")
            feature("trophy.fill", "Arenas", "Save with friends. Stakes stay in your NatWest savings account.")
            Button("Get started") { viewModel.step = .age }.buttonStyle(.novaPrimary)
        }
    }

    private var ageStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("When were you born?").font(.novaTitle).foregroundStyle(NovaColor.brandText)
            Text("If you're 16 or 17, Nova starts in Teen mode: no stakes, no credit offers, and a path to your first real account at 18.")
                .font(.novaBody).foregroundStyle(NovaColor.body)
            Toggle("Use my date of birth", isOn: $viewModel.shareDateOfBirth)
                .tint(NovaColor.action)
                .font(.novaHeadline)
            if viewModel.shareDateOfBirth {
                DatePicker("Date of birth", selection: $viewModel.dateOfBirth, in: ...OnboardingViewModel.latestDateOfBirth, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.novaBody)
            }
            NovaNotice(kind: .info,
                       title: viewModel.stagePreview == .teen ? "You'll start in Teen mode" : "You'll use the full app",
                       message: viewModel.stagePreview == .teen
                       ? "On your 18th birthday Nova moves you to the full app. Your score and history come with you."
                       : "You can change this later in Profile.")
            Button("Continue") { Task { await viewModel.saveAge(model: model) } }.buttonStyle(.novaPrimary)
            Button("Back") { viewModel.step = .welcome }.buttonStyle(.novaSecondary)
        }
    }

    private var bankStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Choose your bank").font(.novaTitle).foregroundStyle(NovaColor.brandText)
            Text("We'll read your transactions to build your predictions.")
                .font(.novaBody).foregroundStyle(NovaColor.body)
            VStack(spacing: Spacing.xs) {
                ForEach(Bank.allCases) { bank in
                    let selected = viewModel.bank == bank
                    Button {
                        viewModel.bank = bank
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            if bank == .natwest {
                                NatWestMark(size: 36)
                            } else {
                                Image(systemName: "building.columns.fill")
                                    .foregroundStyle(NovaColor.action)
                                    .frame(width: 36, height: 36)
                                    .background(NovaColor.lilac, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Text(bank.rawValue).font(.novaBody).foregroundStyle(NovaColor.heading)
                                if bank.isNatWestGroup {
                                    Text("NatWest Group").font(.novaCaption).foregroundStyle(NovaColor.body)
                                }
                            }
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected ? NovaColor.action : NovaColor.hairline)
                                .accessibilityHidden(true)
                        }
                        .padding(Spacing.sm)
                        .frame(minHeight: 56)
                        .background(selected ? NovaColor.lilac : NovaColor.card, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .strokeBorder(selected ? NovaColor.action : NovaColor.hairline, lineWidth: selected ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Button("Continue") { viewModel.step = .data }.buttonStyle(.novaPrimary)
            Button("Back") { viewModel.step = .age }.buttonStyle(.novaSecondary)
        }
    }

    private var dataStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Add your transactions").font(.novaTitle).foregroundStyle(NovaColor.brandText)
            Text("Upload a statement from \(viewModel.bank.rawValue), or try Nova with a year of demo data.")
                .font(.novaBody).foregroundStyle(NovaColor.body)
            if let error = viewModel.errorMessage {
                NovaNotice(kind: .error, title: "Import failed", message: error)
            }
            NovaCard {
                SectionHeader(title: "Upload a statement", systemImage: "doc.fill")
                Text("JSON, CSV or PDF").font(.novaCallout).foregroundStyle(NovaColor.body)
                Button("Choose file") { showImporter = true }.buttonStyle(.novaSecondary)
            }
            NovaCard {
                SectionHeader(title: "Use demo data", systemImage: "wand.and.stars")
                Text("12 months of realistic Manchester spending.").font(.novaCallout).foregroundStyle(NovaColor.body)
                Button("Use demo data") { Task { await viewModel.useDemoData(model: model) } }
                    .buttonStyle(.novaPrimary)
            }
            Button("Back") { viewModel.step = .bank }.buttonStyle(.novaSecondary)
        }
    }

    private var connecting: some View {
        VStack(spacing: Spacing.lg) {
            NatWestMark(size: 72).padding(.top, Spacing.xxl)
            ProgressView().controlSize(.large)
            Text(viewModel.progressText)
                .font(.novaSection).foregroundStyle(NovaColor.heading)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.updatesFrequently)
        }
        .frame(maxWidth: .infinity)
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(NovaColor.action)
                .frame(width: 44, height: 44)
                .background(NovaColor.lilac, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                Text(text).font(.novaCallout).foregroundStyle(NovaColor.body).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? NovaColor.action : NovaColor.track)
                    .frame(height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}
