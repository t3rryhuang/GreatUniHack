import SwiftUI

/// Teen mode: loans from a trusted adult and shared bills. Every on-time payment raises Reliability.
struct FamilyView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = FamilyViewModel()
    @State private var showRequest = false

    var body: some View {
        let family = model.family
        NovaScreen {
            NovaBrandBand {
                Label("Family", systemImage: "person.2.fill").font(.novaHeadline)
                Text("Borrow and share bills with someone you trust.").font(.novaTitle)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Paying on time raises your Reliability, whatever the amount.")
                    .font(.novaCallout).foregroundStyle(.white.opacity(0.85))
            }

            if viewModel.waitingForApproval {
                NovaCard {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text("Waiting for \(viewModel.lenderName) to approve…").font(.novaCallout).foregroundStyle(NovaColor.body)
                    }
                }
            }

            ForEach(family.activeLoans) { loan in
                LoanCard(loan: loan, isBusy: viewModel.busyID == loan.id) {
                    Task { await viewModel.pay(loan, model: model) }
                }
            }

            Button {
                showRequest = true
            } label: {
                Label("Ask for a loan", systemImage: "hand.raised.fill")
            }
            .buttonStyle(.novaSecondary)

            NovaCard {
                SectionHeader(title: "Shared bills", systemImage: "doc.text.fill")
                if family.bills.isEmpty {
                    Text("No shared bills yet.").font(.novaCallout).foregroundStyle(NovaColor.body)
                }
                ForEach(family.bills) { bill in
                    BillRow(bill: bill, isBusy: viewModel.busyID == bill.id) {
                        Task { await viewModel.pay(bill, model: model) }
                    }
                }
            }

            NavigationLink { ParentPreviewView() } label: {
                RowLink(title: "What your parent sees", subtitle: "Totals and progress only, never your transactions", symbol: "eye.fill")
            }
            .buttonStyle(.plain)

            let history = viewModel.history(family)
            if !history.isEmpty {
                NovaCard {
                    SectionHeader(title: "History", systemImage: "clock.fill")
                    ForEach(history.prefix(12)) { payment in
                        PaymentHistoryRow(payment: payment)
                    }
                }
            }

            if !family.repaidLoans.isEmpty {
                NovaCard {
                    SectionHeader(title: "Repaid", systemImage: "checkmark.seal.fill")
                    ForEach(family.repaidLoans) { loan in
                        LabeledContent(loan.purpose, value: loan.amount.gbp)
                            .font(.novaCallout)
                    }
                }
            }
        }
        .navigationTitle("Family")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRequest) {
            LoanRequestView(viewModel: viewModel)
        }
    }
}

private struct LoanCard: View {
    let loan: FamilyLoan
    let isBusy: Bool
    let pay: () -> Void

    var body: some View {
        NovaCard {
            SectionHeader(title: loan.purpose, systemImage: "banknote.fill") {
                Text(loan.status == .requested ? "Waiting" : "\(loan.paidCount) of \(loan.instalments) paid")
                    .font(.novaCaption.weight(.semibold))
                    .foregroundStyle(NovaColor.action)
            }
            Text("\(loan.amount.gbp) from \(loan.lenderName) (\(loan.relationship.lowercased()))")
                .font(.novaCallout).foregroundStyle(NovaColor.body)
            ProbabilityBar(value: loan.progress)
                .accessibilityHidden(false)
                .accessibilityLabel("Repaid")
                .accessibilityValue("\(loan.progress.percent), \(loan.remaining.gbp) left")
            HStack {
                Text("\(loan.paidAmount.gbp) repaid").font(.novaCaption).foregroundStyle(NovaColor.body)
                Spacer()
                Text("\(loan.remaining.gbp) left").font(.novaCaption).foregroundStyle(NovaColor.body)
            }
            if let next = loan.nextPayment {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next instalment").font(.novaCaption).foregroundStyle(NovaColor.body)
                        Text("\(next.amount.gbp) · due \(next.due.formatted(.dateTime.day().month(.wide)))")
                            .font(.novaHeadline).foregroundStyle(NovaColor.heading)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    Button(action: pay) {
                        if isBusy { ProgressView() } else { Text("Pay") }
                    }
                    .buttonStyle(NovaChipStyle(isSelected: true))
                    .disabled(isBusy)
                    .accessibilityLabel("Pay instalment of \(next.amount.gbp)")
                }
            }
        }
    }
}

private struct BillRow: View {
    let bill: SharedBill
    let isBusy: Bool
    let pay: () -> Void

    var body: some View {
        let next = bill.nextDue()
        let overdue = (next?.due ?? .distantFuture) < Calendar.current.startOfDay(for: .now)
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name).font(.novaHeadline).foregroundStyle(NovaColor.heading)
                Text("\(bill.amount.gbp) a month to \(bill.partnerName) · day \(bill.dayOfMonth)")
                    .font(.novaCaption).foregroundStyle(NovaColor.body)
                if let next {
                    Text(overdue ? "Overdue since \(next.due.formatted(.dateTime.day().month()))" : "Next due \(next.due.formatted(.dateTime.weekday(.wide).day().month()))")
                        .font(.novaCaption.weight(.semibold))
                        .foregroundStyle(overdue ? NovaColor.error : NovaColor.action)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer()
            if next != nil {
                Button(action: pay) {
                    if isBusy { ProgressView() } else { Text("Pay") }
                }
                .buttonStyle(NovaChipStyle(isSelected: true))
                .disabled(isBusy)
                .accessibilityLabel("Pay \(bill.name), \(bill.amount.gbp)")
            }
        }
        .padding(.vertical, Spacing.xxs)
    }
}

private struct PaymentHistoryRow: View {
    let payment: ScheduledPayment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.name).font(.novaBody).foregroundStyle(NovaColor.heading)
                Text("Due \(payment.due.formatted(.dateTime.day().month()))").font(.novaCaption).foregroundStyle(NovaColor.body)
            }
            Spacer()
            Text(payment.amount.gbp).font(.novaBody).monospacedDigit().foregroundStyle(NovaColor.heading)
            Text(status)
                .font(.novaCaption.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, Spacing.xs).padding(.vertical, 2)
                .background(color.opacity(0.14), in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    private var status: String { payment.paid == nil ? "Missed" : payment.isOnTime ? "On time" : "Late" }
    private var color: Color { payment.paid == nil ? NovaColor.error : payment.isOnTime ? NovaColor.success : NovaColor.warning }
}

/// Ask a trusted adult for a loan. Any amount from £1.
private struct LoanRequestView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: FamilyViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("What it's for") {
                    TextField("For example: a console", text: $viewModel.purpose)
                }
                Section {
                    Stepper(value: $viewModel.amount, in: 1...1_000, step: viewModel.amount < 20 ? 1 : 10) {
                        LabeledContent("Amount", value: viewModel.amount.gbpWhole)
                    }
                    Stepper(value: $viewModel.instalments, in: 1...12) {
                        LabeledContent("Pay back over", value: "\(viewModel.instalments) month\(viewModel.instalments == 1 ? "" : "s")")
                    }
                } header: {
                    Text("Amount")
                } footer: {
                    Text("About \(viewModel.monthlyAmount.gbp) a month. Small loans count just as much as big ones.")
                }
                Section {
                    TextField("Name", text: $viewModel.lenderName)
                    TextField("Relationship", text: $viewModel.relationship)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(FamilyViewModel.relationshipSuggestions, id: \.self) { item in
                                Button(item) { viewModel.relationship = item }
                                    .buttonStyle(NovaChipStyle(isSelected: viewModel.relationship == item))
                            }
                        }
                    }
                } header: {
                    Text("Who you're asking")
                } footer: {
                    Text("Any adult you trust: a parent, carer, grandparent or key worker.")
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(NovaColor.error) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NovaColor.page)
            .navigationTitle("Ask for a loan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        dismiss()
                        Task { _ = await viewModel.request(model: model) }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isRequesting)
                }
            }
        }
    }
}
