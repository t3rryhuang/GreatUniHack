import SwiftUI

/// Free vs Pro plans and the card form. Ported from upgrade.tsx; prices in pounds.
struct UpgradeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = UpgradeViewModel()
    @State private var showPayment = false

    var body: some View {
        NavigationStack {
            NovaScreen {
                VStack(spacing: Spacing.xs) {
                    Text("Unlock your financial future")
                        .font(.novaTitle).foregroundStyle(NovaColor.brandText).multilineTextAlignment(.center)
                    Text("Personal predictions, scenarios and AI insights.")
                        .font(.novaBody).foregroundStyle(NovaColor.body).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)

                NovaBrandBand {
                    HStack {
                        Text("Pro").font(.novaTitle)
                        Spacer()
                        Text("Most popular")
                            .font(.novaCaption.weight(.semibold))
                            .padding(.horizontal, Spacing.xs).padding(.vertical, 4)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("£1.99").font(.novaHero)
                        Text("/month").font(.novaCallout).opacity(0.8)
                    }
                    Text("7-day free trial. Cancel any time.").font(.novaCallout).opacity(0.85)
                    ForEach(["Daily predictions", "Long-term insights"], id: \.self) { featureRow($0, included: true, inverse: true) }
                    ForEach(ProFeature.allCases) { featureRow($0.title, included: true, inverse: true) }
                    if model.isPro {
                        Label("You're on Pro", systemImage: "checkmark.seal.fill").font(.novaHeadline).padding(.top, Spacing.xs)
                    } else {
                        Button("Start free trial") { showPayment = true }
                            .buttonStyle(.novaInverse)
                            .padding(.top, Spacing.xs)
                    }
                }

                NovaCard {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Free").font(.novaTitle).foregroundStyle(NovaColor.brandText)
                        Spacer()
                        Text("£0").font(.novaSection).foregroundStyle(NovaColor.heading)
                    }
                    ForEach(["Daily predictions", "Long-term insights", "Join arenas", "1 what-if question"], id: \.self) {
                        featureRow($0, included: true)
                    }
                    ForEach(ProFeature.allCases.filter { $0 != .unlimitedWhatIfs }) { featureRow($0.title, included: false) }
                    if !model.isPro {
                        Text("Your current plan").font(.novaCallout.weight(.semibold)).foregroundStyle(NovaColor.muted)
                            .frame(maxWidth: .infinity).padding(.top, Spacing.xs)
                    }
                }
            }
            .navigationTitle("Choose your plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showPayment) { paymentSheet }
        }
    }

    private func featureRow(_ text: String, included: Bool, inverse: Bool = false) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: included ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(inverse ? .white : (included ? NovaColor.success : NovaColor.muted))
                .accessibilityHidden(true)
            Text(text)
                .font(.novaCallout)
                .foregroundStyle(inverse ? .white : (included ? NovaColor.heading : NovaColor.muted))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text), \(included ? "included" : "not included")")
    }

    private var paymentSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Card number", text: $viewModel.cardNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                    HStack {
                        TextField("MM/YY", text: $viewModel.expiry)
                            .keyboardType(.numbersAndPunctuation)
                        Divider()
                        TextField("CVC", text: $viewModel.cvc)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text("Card details")
                } footer: {
                    Text("You won't be charged today. After 7 days you'll pay £1.99 a month. Demo mode: use 4242 4242 4242 4242.")
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(NovaColor.error) }
                }
                Section {
                    Button {
                        Task {
                            if await viewModel.startTrial(model: model) {
                                showPayment = false
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isProcessing { ProgressView().tint(NovaColor.onAction) } else { Text("Start 7-day free trial") }
                    }
                    .buttonStyle(.novaPrimary)
                    .disabled(!viewModel.canPay || viewModel.isProcessing)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showPayment = false } } }
        }
        .presentationDetents([.medium, .large])
    }
}
