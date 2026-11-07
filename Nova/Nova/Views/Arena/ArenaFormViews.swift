import SwiftUI

/// Create an arena: name, mode, target, stake (in pounds) and end date.
struct CreateArenaView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CreateArenaViewModel()
    let onCreated: (Arena) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("For example: Flatmates' February", text: $viewModel.name)
                }
                Section {
                    Picker("Mode", selection: $viewModel.mode) {
                        ForEach(ArenaMode.available(for: model.stage)) { mode in
                            Label(mode.title, systemImage: mode.symbol).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Mode")
                } footer: {
                    Text(viewModel.mode.rule)
                }
                Section(viewModel.mode.targetLabel) {
                    if viewModel.mode == .viceStreak {
                        Picker("Vice to avoid", selection: $viewModel.vice) {
                            ForEach(SpendingCategory.vices(for: model.stage)) { Text($0.rawValue).tag($0) }
                        }
                    } else if viewModel.mode == .mostImproved {
                        Text("Each person is compared with their own spending in the same number of days before the arena started.")
                            .font(.novaCallout).foregroundStyle(NovaColor.body)
                    } else {
                        Stepper(value: $viewModel.target, in: 25...5_000, step: 25) {
                            HStack {
                                Text("Target")
                                Spacer()
                                Text(viewModel.target.gbpWhole).monospacedDigit().foregroundStyle(NovaColor.brandText)
                            }
                        }
                    }
                }
                Section {
                    if !model.isTeen {
                        Picker("Stake per person", selection: $viewModel.stake) {
                            ForEach(CreateArenaViewModel.stakeOptions, id: \.self) { value in
                                Text(value == 0 ? "No stake" : value.gbpWhole).tag(value)
                            }
                        }
                    }
                    DatePicker("Ends", selection: $viewModel.endDate, in: Date.now.addingTimeInterval(86_400)..., displayedComponents: .date)
                } header: {
                    Text(model.isTeen ? "Length" : "Stake and length")
                } footer: {
                    if model.isTeen {
                        Text("Teen arenas never use money. The winner earns points and a badge.")
                    } else if viewModel.stake == 0 {
                        Text("No money changes hands. The winner earns points and a badge.")
                    } else {
                        Text("Your stake moves from your \(model.savingsAccount?.name ?? "savings account") (\(model.savingsAccount?.balance.gbp ?? "£0") available) into the arena pot.")
                    }
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(NovaColor.error) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NovaColor.page)
            .onAppear { viewModel.configure(for: model.stage) }
            .navigationTitle("New arena")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isCreating {
                        ProgressView()
                    } else {
                        Button("Create") {
                            Task {
                                if let arena = await viewModel.create(model: model) {
                                    dismiss()
                                    onCreated(arena)
                                }
                            }
                        }
                        .disabled(!viewModel.isValid)
                    }
                }
            }
        }
    }
}

/// Join an arena with a 6-digit code.
struct JoinArenaView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = JoinArenaViewModel()
    @FocusState private var focused: Bool
    let onJoined: (Arena) -> Void

    var body: some View {
        NavigationStack {
            NovaScreen {
                Text("Enter the 6-digit code your friend shared.")
                    .font(.novaBody).foregroundStyle(NovaColor.body)
                TextField("000000", text: $viewModel.code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .novaField()
                    .accessibilityLabel("Join code")
                    .onChange(of: viewModel.code) { _, newValue in
                        if newValue.count == 6 { Task { await viewModel.lookUp(model: model) } }
                    }
                Text("Demo codes: \(MockArenaService.demoJoinCodes(for: model.stage).joined(separator: " or "))")
                    .font(.novaCaption).foregroundStyle(NovaColor.muted)

                if viewModel.isWorking && viewModel.preview == nil {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if let error = viewModel.errorMessage {
                    NovaNotice(kind: .error, title: "Can't join", message: error)
                }
                if let arena = viewModel.preview {
                    NovaCard {
                        Label(arena.mode.title, systemImage: arena.mode.symbol).font(.novaCallout).foregroundStyle(NovaColor.action)
                        Text(arena.name).font(.novaSection).foregroundStyle(NovaColor.brandText)
                        Text(arena.mode.rule).font(.novaCallout).foregroundStyle(NovaColor.body)
                        HStack {
                            Metric(label: "Stake", value: arena.isMoneyFree ? "None" : arena.stakeAmount.gbpWhole)
                            Spacer()
                            Metric(label: "Members", value: "\(arena.members.count)")
                            Spacer()
                            Metric(label: "Ends", value: arena.endDate.formatted(.dateTime.day().month()))
                        }
                        Button {
                            Task {
                                if let joined = await viewModel.join(model: model) {
                                    dismiss()
                                    onJoined(joined)
                                }
                            }
                        } label: {
                            if viewModel.isWorking { ProgressView() } else { Text(arena.isMoneyFree ? "Join" : "Join and stake \(arena.stakeAmount.gbpWhole)") }
                        }
                        .buttonStyle(.novaPrimary)
                    }
                }
            }
            .navigationTitle("Join arena")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { focused = true }
        }
    }
}
