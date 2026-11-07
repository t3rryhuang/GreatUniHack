import SwiftUI

/// Profile: plan, stats, savings account, account info, data and sign out.
/// Shown as a sheet from the avatar button on every tab.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false
    @State private var confirmCancel = false
    @State private var showSavings = false
    @State private var showUpgrade = false
    @State private var showAddTransaction = false
    @State private var isSwitchingStage = false

    var body: some View {
        List {
            if let user = model.user {
                Section {
                    HStack(spacing: Spacing.md) {
                        AvatarView(initials: initials(user.name), size: 60, highlighted: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name).font(.novaSection).foregroundStyle(NovaColor.heading)
                            Text(user.email).font(.novaCallout).foregroundStyle(NovaColor.body)
                            if model.isTeen {
                                Text("Teen mode")
                                    .font(.novaCaption.weight(.semibold))
                                    .foregroundStyle(NovaColor.action)
                                    .padding(.horizontal, Spacing.xs).padding(.vertical, 2)
                                    .background(NovaColor.lilac, in: Capsule())
                            }
                        }
                    }
                    .padding(.vertical, Spacing.xxs)
                    .accessibilityElement(children: .combine)
                }
            }

            if !model.isPro {
                Section {
                    Button {
                        showUpgrade = true
                    } label: {
                        Label("Upgrade to Pro", systemImage: "sparkles")
                    }
                }
            }

            Section("Your stats") {
                LabeledContent("Average monthly spend", value: model.summary.avgMonthly.gbpWhole)
                LabeledContent("Average daily spend", value: model.summary.avgDaily.gbp)
                LabeledContent("Savings rate", value: "\(Int(model.summary.savingsRate))%")
                LabeledContent("Transactions", value: "\(model.transactions.count)")
            }

            Section {
                Button {
                    showSavings = true
                } label: {
                    LabeledContent {
                        Text(model.savingsAccount?.balance.gbp ?? "–").monospacedDigit()
                    } label: {
                        Label(model.savingsAccount?.name ?? "Savings account", systemImage: "building.columns")
                    }
                }
            } header: {
                Text("Savings account")
            } footer: {
                Text("Arena stakes are held from, and prize pots paid into, this account.")
            }

            Section("Account") {
                LabeledContent("Bank", value: model.user?.bank.rawValue ?? "NatWest")
                LabeledContent("Member since", value: model.user?.memberSince.formatted(.dateTime.month(.wide).year()) ?? "–")
                LabeledContent("City", value: "Manchester")
            }

            Section {
                Button {
                    showAddTransaction = true
                } label: {
                    Label("Import or add transactions", systemImage: "square.and.arrow.down")
                }
                Button(role: .destructive) {
                    confirmClear = true
                } label: {
                    Label("Clear all data", systemImage: "trash")
                }
            } header: {
                Text("Your data")
            } footer: {
                Text("Supports PDF, JSON and CSV statements.")
            }

            Section {
                Picker("Mode", selection: Binding(
                    get: { model.stage },
                    set: { newStage in
                        Task {
                            isSwitchingStage = true
                            await model.switchDemoStage(to: newStage)
                            isSwitchingStage = false
                        }
                    }
                )) {
                    ForEach(LifeStage.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(isSwitchingStage)
                .accessibilityLabel("Demo mode")
                if isSwitchingStage {
                    HStack(spacing: Spacing.xs) {
                        ProgressView()
                        Text("Loading \(model.stage.title.lowercased()) demo data…").font(.novaCallout).foregroundStyle(NovaColor.body)
                    }
                }
            } header: {
                Text("Demo")
            } footer: {
                Text("Teen mode is for 16 and 17-year-olds. Switching loads matching demo data.")
            }

            Section {
                if model.isPro && !AppModel.allFeaturesUnlocked {
                    Button("Cancel Pro subscription", role: .destructive) { confirmCancel = true }
                }
                Button("Sign out", role: .destructive) {
                    dismiss()
                    Task { await model.signOut() }
                }
            }

            Section {
                HStack {
                    Spacer()
                    VStack(spacing: Spacing.xs) {
                        NatWestLogo(height: 28)
                        Text("Nova 1.0.0").font(.novaCaption).foregroundStyle(NovaColor.muted)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(NovaColor.page)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .task { await model.refreshSavings() }
        .confirmationDialog("Clear all data?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear all data", role: .destructive) {
                dismiss()
                Task { await model.clearAllData() }
            }
        } message: {
            Text("This removes every transaction from Nova. Your bank account is not affected.")
        }
        .confirmationDialog("Cancel Pro?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel subscription", role: .destructive) {
                Task { model.setPlan(await model.services.subscription.cancel()) }
            }
        } message: {
            Text("You'll go back to the free plan.")
        }
        .sheet(isPresented: $showSavings) { SavingsAccountView() }
        .sheet(isPresented: $showUpgrade) { UpgradeView() }
        .sheet(isPresented: $showAddTransaction) { AddTransactionView() }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

/// Savings account details and activity. Replaces the original SolanaWalletModal.
struct SavingsAccountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isTopping = false

    var body: some View {
        NavigationStack {
            NovaScreen {
                if let account = model.savingsAccount {
                    NovaBrandBand {
                        Text(account.name).font(.novaHeadline)
                        Text(account.balance.gbp).font(.novaHero).monospacedDigit()
                        Text("\(account.sortCode) · \(account.maskedNumber) · \(String(format: "%.2f", account.interestRate))% AER")
                            .font(.novaCallout).foregroundStyle(.white.opacity(0.85))
                    }
                    Button {
                        Task {
                            isTopping = true
                            _ = try? await model.services.savings.topUp(50)
                            await model.refreshSavings()
                            isTopping = false
                        }
                    } label: {
                        if isTopping { ProgressView() } else { Label("Move £50 from current account", systemImage: "arrow.down.circle") }
                    }
                    .buttonStyle(.novaSecondary)
                    NovaCard {
                        SectionHeader(title: "Recent activity", systemImage: "clock")
                        ForEach(account.activity.prefix(15)) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.novaBody).foregroundStyle(NovaColor.heading)
                                    Text("\(item.date.formatted(date: .abbreviated, time: .omitted)) · \(item.reference)")
                                        .font(.novaCaption).foregroundStyle(NovaColor.body)
                                }
                                Spacer()
                                Text((item.amount > 0 ? "+" : "−") + item.amount.magnitude.gbp)
                                    .font(.novaBody.weight(.semibold))
                                    .foregroundStyle(item.amount > 0 ? NovaColor.success : NovaColor.heading)
                                    .monospacedDigit()
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                } else {
                    LoadingCard(label: "Loading your account…")
                }
            }
            .navigationTitle("Savings account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
