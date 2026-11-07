import SwiftUI

/// Log an expense by hand, or import a statement. Ported from add-transaction.tsx.
struct AddTransactionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddTransactionViewModel()
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import from file", systemImage: "doc.badge.plus")
                    }
                    if let message = viewModel.importMessage {
                        Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(NovaColor.success)
                    }
                } footer: {
                    Text("PDF, JSON or CSV. New transactions are merged with your existing data.")
                }

                Section {
                    TextField("Description, for example Pret A Manger", text: $viewModel.description)
                        .onChange(of: viewModel.description) { viewModel.descriptionChanged() }
                    HStack {
                        Text("£").foregroundStyle(NovaColor.body)
                        TextField("0.00", text: $viewModel.amountText)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Category", selection: Binding(
                        get: { viewModel.category },
                        set: { viewModel.category = $0; viewModel.categoryWasPicked = true }
                    )) {
                        ForEach(SpendingCategory.expenseCategories) { category in
                            Label(category.rawValue, systemImage: category.symbol).tag(category)
                        }
                    }
                    DatePicker("Date and time", selection: $viewModel.date, in: ...Date.now)
                } header: {
                    Text("Or add manually")
                } footer: {
                    Text("All transactions are logged as expenses.")
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(NovaColor.error) }
                }

                if !model.hasData {
                    Section {
                        Button("Use demo data instead") {
                            Task {
                                try? await model.loadDemoData()
                                await model.finishOnboarding(bank: model.user?.bank ?? .natwest)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NovaColor.page)
            .navigationTitle("Log expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task { if await viewModel.save(model: model) { dismiss() } }
                        }
                        .disabled(!viewModel.canSave)
                    }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: TransactionImporter.allowedTypes) { result in
                if case .success(let url) = result {
                    Task { await viewModel.importFile(at: url, model: model) }
                }
            }
        }
    }
}
