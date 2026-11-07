import SwiftUI

/// Teen-mode Piggy Bank. Shake the phone (or tap Shake) to hear your savings:
/// the sound grows with progress to YOUR goal, never with the £ amount.
struct PiggyBankView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = PiggyBankViewModel()
    @State private var isVisible = false
    @State private var showGoalForm = false
    @AppStorage("nova.piggy.sound") private var soundOn = true
    @AppStorage("nova.piggy.haptics") private var hapticsOn = true
    @AppStorage("nova.piggy.hideAmount") private var hideAmount = true
    @AppStorage("nova.piggy.rewards") private var rewardsOn = true
    @AppStorage("nova.piggy.shareWithParent") private var shareWithParent = false

    var body: some View {
        NovaScreen {
            if let piggy = model.piggy {
                pigCard(piggy)
                if let message = viewModel.message {
                    NovaNotice(kind: .success, title: "Saved", message: message)
                }
                goalCard(piggy)
                addMoneyCard
                promiseCard(piggy)
                rewardsCard(piggy)
                settingsCard
            } else {
                NovaCard {
                    SectionHeader(title: "Start a Piggy Bank", systemImage: "sparkles")
                    Text("Pick something to save for. We suggest a goal from your own income, so it fits you.")
                        .font(.novaBody).foregroundStyle(NovaColor.body)
                    Button("Set a goal") { viewModel.prepareGoalForm(model: model); showGoalForm = true }
                        .buttonStyle(.novaPrimary)
                }
            }
        }
        .navigationTitle("Piggy Bank")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false; viewModel.stopSound() }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            guard isVisible, model.piggy != nil else { return }
            viewModel.shake(model: model, soundOn: soundOn, hapticsOn: hapticsOn)
        }
        #if DEBUG
        .task {
            // -NovaAutoShake shakes once after opening (the Simulator's Device > Shake does the same).
            guard ProcessInfo.processInfo.arguments.contains("-NovaAutoShake") else { return }
            try? await Task.sleep(for: .seconds(1.5))
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        #endif
        .sheet(isPresented: $showGoalForm) { GoalFormView(viewModel: viewModel) }
        .alert("Couldn't save", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(viewModel.errorMessage ?? "") }
    }

    private func pigCard(_ piggy: PiggyBank) -> some View {
        let progress = viewModel.progress(model: model)
        let goal = PiggyRules.effectiveGoal(piggy, scale: model.hardshipScale)
        let spoken = "You've saved \(piggy.saved.gbp), \(progress.percent) of your goal"
        return NovaCard(padding: Spacing.lg) {
            VStack(spacing: Spacing.md) {
                PigView(progress: progress, shakeCount: viewModel.shakeCount, tier: viewModel.lastTier)
                    .frame(maxWidth: .infinity)
                if viewModel.isRevealed {
                    VStack(spacing: Spacing.xxs) {
                        Text("\(progress.percent) of your goal").font(.novaTitle).foregroundStyle(NovaColor.heading)
                        if hideAmount && !viewModel.amountVisible {
                            Button("Tap to show amount") { viewModel.amountVisible = true }
                                .font(.novaCallout)
                        } else {
                            Text("\(piggy.saved.gbp) of \(goal.gbp) saved").font(.novaHeadline).foregroundStyle(NovaColor.body).monospacedDigit()
                        }
                    }
                    .transition(.opacity)
                } else {
                    Text("Shake your phone to hear your savings").font(.novaHeadline).foregroundStyle(NovaColor.heading)
                }
                Button {
                    viewModel.shake(model: model, soundOn: soundOn, hapticsOn: hapticsOn)
                } label: {
                    Label("Shake", systemImage: "iphone.radiowaves.left.and.right")
                }
                .buttonStyle(.novaSecondary)
                .accessibilityHint("Plays the piggy bank sound and shows how much you've saved")
                Text("The sound gets fuller as you get closer to your goal. In the Simulator use Device > Shake.")
                    .font(.novaCaption).foregroundStyle(NovaColor.muted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isRevealed)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Piggy Bank. \(spoken)")
        .accessibilityAction(named: "Shake") { viewModel.shake(model: model, soundOn: soundOn, hapticsOn: hapticsOn) }
    }

    private func goalCard(_ piggy: PiggyBank) -> some View {
        let progress = viewModel.progress(model: model)
        return NovaCard {
            SectionHeader(title: piggy.goalName, systemImage: "flag.fill") {
                Button("Edit") { viewModel.prepareGoalForm(model: model); showGoalForm = true }.font(.novaCallout)
            }
            ProbabilityBar(value: progress, tint: NovaColor.chartWatermelon)
            HStack {
                Text("\(progress.percent) there").font(.novaCallout.weight(.semibold)).foregroundStyle(NovaColor.heading)
                Spacer()
                if let date = piggy.targetDate {
                    Text("by \(date.formatted(.dateTime.day().month(.wide)))").font(.novaCaption).foregroundStyle(NovaColor.body)
                }
            }
            if model.hardshipScale < 1 {
                Text("Your income dropped this month, so we've eased this goal to \(PiggyRules.effectiveGoal(piggy, scale: model.hardshipScale).gbp). That's OK.")
                    .font(.novaCaption).foregroundStyle(NovaColor.info)
            }
            if piggy.goalReachedAt != nil {
                Label("Goal reached! Badge earned.", systemImage: "rosette").font(.novaHeadline).foregroundStyle(NovaColor.chartYolk)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var addMoneyCard: some View {
        NovaCard {
            SectionHeader(title: "Add money", systemImage: "plus.circle.fill")
            HStack(spacing: Spacing.xs) {
                ForEach(PiggyBankViewModel.quickAmounts, id: \.self) { amount in
                    Button(amount.gbpWhole) { viewModel.depositAmount = amount }
                        .buttonStyle(NovaChipStyle(isSelected: viewModel.depositAmount == amount))
                }
            }
            Stepper(value: $viewModel.depositAmount, in: 1...500, step: 1) {
                Text("Amount: \(viewModel.depositAmount.gbpWhole)").font(.novaCallout)
            }
            Button {
                Task { await viewModel.deposit(model: model, rewardsOn: rewardsOn) }
            } label: {
                if viewModel.isWorking { ProgressView() } else { Text("Add \(viewModel.depositAmount.gbpWhole)") }
            }
            .buttonStyle(.novaPrimary)
            .disabled(viewModel.isWorking)
            Text("Any amount from £1 counts. Every deposit grows your saving streak.").font(.novaCaption).foregroundStyle(NovaColor.muted)
        }
    }

    private func promiseCard(_ piggy: PiggyBank) -> some View {
        NovaCard {
            SectionHeader(title: "Promise to myself", systemImage: "hand.raised.fingers.spread.fill")
            Text("A weekly transfer into your Piggy Bank, from £1. Keeping it on time counts towards Reliability, just like a bill.")
                .font(.novaCallout).foregroundStyle(NovaColor.body)
            if let promise = piggy.promise {
                let cycles = promise.cycles().filter { $0.due <= .now }
                Text("\(promise.amount.gbp) every \(Calendar.current.weekdaySymbols[(promise.weekday - 1) % 7]) · \(cycles.filter(\.isOnTime).count) of \(cycles.count) kept")
                    .font(.novaHeadline).foregroundStyle(NovaColor.heading)
                if let next = promise.nextDue() {
                    Button("Keep this week's promise (\(next.amount.gbp))") {
                        Task { await viewModel.keepPromise(model: model, rewardsOn: rewardsOn) }
                    }
                    .buttonStyle(.novaSecondary)
                    .disabled(viewModel.isWorking)
                }
                Button("Stop promise", role: .destructive) { Task { await viewModel.savePromise(model: model, on: false) } }
                    .font(.novaCallout)
            } else {
                Stepper(value: $viewModel.promiseAmount, in: 1...100, step: 1) {
                    Text("\(viewModel.promiseAmount.gbpWhole) a week").font(.novaCallout)
                }
                Picker("Day", selection: $viewModel.promiseWeekday) {
                    ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1]).tag($0) }
                }
                Button("Start my promise") { Task { await viewModel.savePromise(model: model, on: true) } }
                    .buttonStyle(.novaSecondary)
            }
        }
    }

    private func rewardsCard(_ piggy: PiggyBank) -> some View {
        NovaCard {
            SectionHeader(title: "Matched bonus", systemImage: "gift.fill")
            Text("Reach your goal and get \(Int(RewardsConfig.matchRate * 100))% of the first \(RewardsConfig.matchOnFirst.gbpWhole) you saved, up to \(RewardsConfig.maxBonus.gbp). The same for everyone, whatever your goal.")
                .font(.novaCallout).foregroundStyle(NovaColor.body)
            if piggy.bonusPaid > 0 {
                Label("\(piggy.bonusPaid.gbp) bonus added", systemImage: "checkmark.circle.fill").font(.novaCallout.weight(.semibold)).foregroundStyle(NovaColor.success)
            }
            Text(RewardsConfig.label).font(.novaCaption).foregroundStyle(NovaColor.muted)
        }
    }

    private var settingsCard: some View {
        NovaCard {
            SectionHeader(title: "Settings", systemImage: "gearshape.fill")
            Toggle("Sound", isOn: $soundOn).tint(NovaColor.action)
            Toggle("Haptics", isOn: $hapticsOn).tint(NovaColor.action)
            Toggle("Hide amount until I tap", isOn: $hideAmount).tint(NovaColor.action)
            Toggle("Rewards", isOn: $rewardsOn).tint(NovaColor.action)
            Toggle("Show my parent the amount", isOn: $shareWithParent).tint(NovaColor.action)
            Text("Your parent only sees your % to goal unless you turn this on. Sound follows your silent switch.")
                .font(.novaCaption).foregroundStyle(NovaColor.muted)
        }
        .font(.novaCallout)
    }
}

private struct GoalFormView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: PiggyBankViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you saving for?") {
                    TextField("For example: gig tickets", text: $viewModel.goalName)
                }
                Section {
                    Stepper(value: $viewModel.goalAmount, in: 1...5_000, step: viewModel.goalAmount < 50 ? 1 : 5) {
                        LabeledContent("Goal", value: viewModel.goalAmount.gbpWhole)
                    }
                    Button("Use suggestion: \(PiggyRules.suggestedGoal(monthlyIncome: model.summary.monthlyIncome).gbpWhole)") {
                        viewModel.goalAmount = PiggyRules.suggestedGoal(monthlyIncome: model.summary.monthlyIncome)
                    }
                } header: {
                    Text("Amount")
                } footer: {
                    Text("We suggest 10% of a month's income, so the goal fits you.")
                }
                Section {
                    Toggle("Set a date", isOn: $viewModel.hasTargetDate)
                    if viewModel.hasTargetDate {
                        DatePicker("By", selection: $viewModel.targetDate, in: Date.now..., displayedComponents: .date)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NovaColor.page)
            .navigationTitle("Your goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await viewModel.saveGoal(model: model); dismiss() } }
                }
            }
        }
    }
}
