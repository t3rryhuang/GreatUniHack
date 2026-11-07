import Foundation

// Family loans and shared bills for Teen mode. The lender or bill partner can be
// any trusted adult (parent, carer, grandparent, key worker). Amounts start at £1:
// the Readiness Score counts the on-time rate, never the size.

struct FamilyPayment: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var due: Date
    var amount: Double
    var paid: Date?

    var isOnTime: Bool {
        guard let paid else { return false }
        return paid <= due.addingTimeInterval(ReadinessRules.graceDays * 86_400)
    }
}

struct FamilyLoan: Codable, Hashable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable { case requested, approved, repaid, declined }

    var id = UUID()
    var purpose: String
    var amount: Double
    var instalments: Int
    var lenderName: String
    /// Free text, for example "Mum", "Grandad" or "Key worker".
    var relationship: String
    var requestedAt: Date
    var approvedAt: Date?
    var status: Status
    var payments: [FamilyPayment]

    var paidAmount: Double { payments.filter { $0.paid != nil }.reduce(0) { $0 + $1.amount } }
    var remaining: Double { max(0, amount - paidAmount) }
    var nextPayment: FamilyPayment? { payments.filter { $0.paid == nil }.min { $0.due < $1.due } }
    var paidCount: Int { payments.filter { $0.paid != nil }.count }
    var progress: Double { amount > 0 ? paidAmount / amount : 0 }

    /// Monthly instalments starting one month after approval. The last one takes any rounding.
    static func schedule(amount: Double, instalments: Int, from start: Date, calendar: Calendar = .current) -> [FamilyPayment] {
        let count = max(1, instalments)
        let each = (amount / Double(count) * 100).rounded(.down) / 100
        return (1...count).compactMap { index in
            guard let due = calendar.date(byAdding: .month, value: index, to: start) else { return nil }
            let value = index == count ? ((amount - each * Double(count - 1)) * 100).rounded() / 100 : each
            return FamilyPayment(due: due, amount: value)
        }
    }
}

struct SharedBill: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var amount: Double
    var dayOfMonth: Int
    var partnerName: String
    var relationship: String
    var startDate: Date
    /// Payments made, keyed by the due date they cover.
    var payments: [FamilyPayment]

    /// Every monthly due date from the start up to and including next month's.
    func cycles(now: Date = .now, calendar: Calendar = .current) -> [FamilyPayment] {
        var result: [FamilyPayment] = []
        var month = calendar.dateInterval(of: .month, for: startDate)?.start ?? startDate
        let limit = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        while month <= limit {
            let due = ReadinessRules.expectedDate(day: dayOfMonth, near: calendar.date(byAdding: .day, value: 14, to: month) ?? month, calendar: calendar)
            if due >= calendar.startOfDay(for: startDate) {
                let paid = payments.first { calendar.isDate($0.due, inSameDayAs: due) }
                result.append(FamilyPayment(id: paid?.id ?? UUID(), due: due, amount: amount, paid: paid?.paid))
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result
    }

    /// The earliest unpaid cycle (an overdue one first, so it can be caught up).
    func nextDue(now: Date = .now) -> FamilyPayment? {
        cycles(now: now).filter { $0.paid == nil }.min { $0.due < $1.due }
    }
}

struct FamilyState: Codable, Hashable, Sendable {
    var loans: [FamilyLoan] = []
    var bills: [SharedBill] = []

    /// Every loan instalment and shared-bill cycle that is due, for Reliability.
    func scheduledPayments(now: Date = .now) -> [ScheduledPayment] {
        let loanPayments = loans.filter { $0.status == .approved || $0.status == .repaid }.flatMap { loan in
            loan.payments.map { ScheduledPayment(name: "\(loan.purpose) repayment", amount: $0.amount, due: $0.due, paid: $0.paid) }
        }
        let billPayments = bills.flatMap { bill in
            bill.cycles(now: now).map { ScheduledPayment(name: bill.name, amount: $0.amount, due: $0.due, paid: $0.paid) }
        }
        return (loanPayments + billPayments).sorted { $0.due < $1.due }
    }

    var activeLoans: [FamilyLoan] { loans.filter { $0.status == .approved || $0.status == .requested } }
    var repaidLoans: [FamilyLoan] { loans.filter { $0.status == .repaid } }
}
