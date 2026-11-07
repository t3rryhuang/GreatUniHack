import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
final class LoginViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign in", signUp = "Create account"
        var id: String { rawValue }
    }

    var mode: Mode = .signIn
    var name = ""
    var email = ""
    var password = ""
    private(set) var isWorking = false
    var errorMessage: String?

    var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && (mode == .signIn || !name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func submit(model: AppModel) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let user = mode == .signIn
                ? try await model.services.auth.signIn(email: email, password: password)
                : try await model.services.auth.signUp(name: name, email: email, password: password)
            errorMessage = nil
            await model.didSignIn(user, isNewAccount: mode == .signUp)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome, age, bank, data, connecting
    }

    var step: Step = .welcome
    var bank: Bank = .natwest
    /// Optional. 16 and 17-year-olds start in Teen mode; under-16s can't pick a date.
    var dateOfBirth = Calendar.current.date(byAdding: .year, value: -20, to: .now) ?? .now
    var shareDateOfBirth = true

    /// Latest date of birth allowed: 16 years ago today.
    static var latestDateOfBirth: Date { Calendar.current.date(byAdding: .year, value: -16, to: .now) ?? .now }

    var stagePreview: LifeStage { shareDateOfBirth ? LifeStage.from(dateOfBirth: dateOfBirth) : .adult }

    func saveAge(model: AppModel) async {
        await model.setDateOfBirth(shareDateOfBirth ? dateOfBirth : nil)
        step = .bank
    }
    private(set) var progressText = ""
    var errorMessage: String?

    func useDemoData(model: AppModel) async {
        step = .connecting
        progressText = "Connecting to \(bank.rawValue)…"
        do {
            try await Task.sleep(for: .milliseconds(600))
            progressText = "Reading your transactions…"
            try await model.loadDemoData()
            progressText = "Building your predictions…"
            try await Task.sleep(for: .milliseconds(500))
            await model.finishOnboarding(bank: bank)
        } catch {
            errorMessage = error.localizedDescription
            step = .data
        }
    }

    func importFile(at url: URL, model: AppModel) async {
        step = .connecting
        progressText = "Reading your statement…"
        do {
            try await TransactionImporter.importFile(at: url, model: model)
            progressText = "Building your predictions…"
            await model.finishOnboarding(bank: bank)
        } catch {
            errorMessage = error.localizedDescription
            step = .data
        }
    }
}

@Observable
final class AddTransactionViewModel {
    var description = ""
    var amountText = ""
    var date = Date.now
    var category: SpendingCategory = .other
    var categoryWasPicked = false
    private(set) var isSaving = false
    var errorMessage: String?
    var importMessage: String?

    var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "£", with: ""))
    }

    var canSave: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty && (amount ?? 0) > 0
    }

    /// Suggests a category from the description until the user picks one.
    func descriptionChanged() {
        guard !categoryWasPicked else { return }
        category = SpendingCategory.categorise(description)
    }

    func save(model: AppModel) async -> Bool {
        guard let amount, canSave else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            // Every manual transaction is logged as an expense, as in the original app.
            try await model.addTransaction(Transaction(
                date: date,
                description: description.trimmingCharacters(in: .whitespaces),
                amount: -abs(amount),
                category: category,
                isManual: true
            ))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func importFile(at url: URL, model: AppModel) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let before = model.transactions.count
            try await TransactionImporter.importFile(at: url, model: model)
            importMessage = "Imported \(model.transactions.count - before) new transactions."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Reads a picked file and hands it to the transaction service.
enum TransactionImporter {
    static let allowedTypes: [UTType] = [.json, .commaSeparatedText, .pdf]

    static func importFile(at url: URL, model: AppModel) async throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let type: ImportFileType = switch url.pathExtension.lowercased() {
        case "json": .json
        case "csv": .csv
        case "pdf": .pdf
        default: throw ServiceError.unreadableFile
        }
        try await model.importStatement(data, type: type)
    }
}

@Observable
final class UpgradeViewModel {
    var cardNumber = ""
    var expiry = ""
    var cvc = ""
    private(set) var isProcessing = false
    var errorMessage: String?

    var canPay: Bool {
        cardNumber.filter(\.isNumber).count == 16 && expiry.count >= 4 && cvc.count >= 3
    }

    func startTrial(model: AppModel) async -> Bool {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let plan = try await model.services.subscription.startProTrial(cardNumber: cardNumber, expiry: expiry, cvc: cvc)
            model.setPlan(plan)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
