import Foundation

/// Family loans and shared bills kept on this device (`family.json`).
/// Used by both containers. The "parent" is simulated: requests are approved after a short delay.
final class LocalFamilyService: FamilyServicing {
    private let storeName = "family.json"
    private var data: FamilyState

    init() {
        data = LocalStore.load(FamilyState.self, from: storeName) ?? FamilyState()
    }

    func state() async -> FamilyState { data }

    func requestLoan(purpose: String, amount: Double, instalments: Int, lenderName: String, relationship: String) async throws -> FamilyLoan {
        guard amount >= 1 else { throw ServiceError.invalidAmount }
        await simulateLatency(400)
        let loan = FamilyLoan(
            purpose: purpose.trimmingCharacters(in: .whitespaces),
            amount: (amount * 100).rounded() / 100,
            instalments: max(1, min(12, instalments)),
            lenderName: lenderName.trimmingCharacters(in: .whitespaces),
            relationship: relationship.trimmingCharacters(in: .whitespaces),
            requestedAt: .now,
            status: .requested,
            payments: []
        )
        data.loans.insert(loan, at: 0)
        persist()
        return loan
    }

    func awaitApproval(loanID: UUID) async throws -> FamilyLoan {
        await simulateLatency(2_500)
        guard let index = data.loans.firstIndex(where: { $0.id == loanID }) else { throw ServiceError.nothingDue }
        if data.loans[index].status == .requested {
            let approvedAt = Date.now
            data.loans[index].status = .approved
            data.loans[index].approvedAt = approvedAt
            data.loans[index].payments = FamilyLoan.schedule(amount: data.loans[index].amount, instalments: data.loans[index].instalments, from: approvedAt)
            persist()
        }
        return data.loans[index]
    }

    func payInstalment(loanID: UUID) async throws -> FamilyPayment {
        await simulateLatency(400)
        guard let index = data.loans.firstIndex(where: { $0.id == loanID }),
              let paymentIndex = data.loans[index].payments.indices
                .filter({ data.loans[index].payments[$0].paid == nil })
                .min(by: { data.loans[index].payments[$0].due < data.loans[index].payments[$1].due })
        else { throw ServiceError.nothingDue }
        data.loans[index].payments[paymentIndex].paid = .now
        if data.loans[index].payments.allSatisfy({ $0.paid != nil }) { data.loans[index].status = .repaid }
        persist()
        return data.loans[index].payments[paymentIndex]
    }

    func addBill(name: String, amount: Double, dayOfMonth: Int, partnerName: String, relationship: String) async throws -> SharedBill {
        guard amount >= 1 else { throw ServiceError.invalidAmount }
        let bill = SharedBill(name: name, amount: amount, dayOfMonth: max(1, min(28, dayOfMonth)),
                              partnerName: partnerName, relationship: relationship, startDate: .now, payments: [])
        data.bills.append(bill)
        persist()
        return bill
    }

    func payBill(billID: UUID) async throws -> FamilyPayment {
        await simulateLatency(400)
        guard let index = data.bills.firstIndex(where: { $0.id == billID }),
              var next = data.bills[index].nextDue() else { throw ServiceError.nothingDue }
        next.paid = .now
        data.bills[index].payments.append(next)
        persist()
        return next
    }

    func resetDemo(profile: DemoProfile) async {
        data = profile.stage == .teen ? MockDataFactory.teenFamily(profile) : FamilyState()
        persist()
    }

    private func persist() { LocalStore.save(data, to: storeName) }
}
