import Foundation
import Observation

@Observable
final class FamilyViewModel {
    // Loan request form
    var purpose = "A console"
    var amount = 200.0
    var instalments = 4
    var lenderName = "Mum"
    var relationship = "Parent"
    static let relationshipSuggestions = ["Parent", "Carer", "Grandparent", "Aunt or uncle", "Key worker"]

    private(set) var isRequesting = false
    private(set) var waitingForApproval = false
    private(set) var busyID: UUID?
    var errorMessage: String?

    var isFormValid: Bool {
        amount >= 1 && !purpose.trimmingCharacters(in: .whitespaces).isEmpty && !lenderName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var monthlyAmount: Double { amount / Double(max(1, instalments)) }

    func request(model: AppModel) async -> Bool {
        isRequesting = true
        waitingForApproval = true
        defer { isRequesting = false; waitingForApproval = false }
        do {
            try await model.requestFamilyLoan(purpose: purpose, amount: amount, instalments: instalments,
                                              lenderName: lenderName, relationship: relationship)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func pay(_ loan: FamilyLoan, model: AppModel) async {
        busyID = loan.id
        defer { busyID = nil }
        do { try await model.payInstalment(loan) } catch { model.errorMessage = error.localizedDescription }
    }

    func pay(_ bill: SharedBill, model: AppModel) async {
        busyID = bill.id
        defer { busyID = nil }
        do { try await model.payBill(bill) } catch { model.errorMessage = error.localizedDescription }
    }

    /// Every paid or missed payment, newest first.
    func history(_ family: FamilyState, now: Date = .now) -> [ScheduledPayment] {
        family.scheduledPayments(now: now)
            .filter { $0.paid != nil || $0.due < now.addingTimeInterval(-ReadinessRules.graceDays * 86_400) }
            .sorted { ($0.paid ?? $0.due) > ($1.paid ?? $1.due) }
    }
}
