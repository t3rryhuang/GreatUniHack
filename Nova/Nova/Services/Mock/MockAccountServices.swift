import Foundation

/// Mock sign-in. Any email with a password of 6 or more characters works.
final class MockAuthService: AuthServicing {
    private let storeName = "user.json"
    private(set) var currentUser: UserProfile?

    init() {
        currentUser = LocalStore.load(UserProfile.self, from: storeName)
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        await simulateLatency(700)
        guard email.contains("@"), password.count >= 6 else { throw ServiceError.invalidCredentials }
        let local = email.split(separator: "@").first.map(String.init) ?? "Alex"
        let name = local.split(whereSeparator: { $0 == "." || $0 == "_" })
            .map { $0.capitalized }
            .joined(separator: " ")
        let user = UserProfile(name: name.isEmpty ? "Alex" : name, email: email.lowercased())
        currentUser = user
        LocalStore.save(user, to: storeName)
        return user
    }

    func signUp(name: String, email: String, password: String) async throws -> UserProfile {
        await simulateLatency(800)
        guard email.contains("@"), password.count >= 6 else { throw ServiceError.invalidCredentials }
        let user = UserProfile(name: name.trimmingCharacters(in: .whitespaces), email: email.lowercased())
        currentUser = user
        LocalStore.save(user, to: storeName)
        return user
    }

    func signOut() async {
        currentUser = nil
        LocalStore.remove(storeName)
    }

    func updateBank(_ bank: Bank) async {
        currentUser?.bank = bank
        if let currentUser { LocalStore.save(currentUser, to: storeName) }
    }
}

/// Mock NatWest savings account that holds arena stakes and receives prize pots.
final class MockSavingsService: SavingsServicing {
    private let storeName = "savings.json"
    private var state: SavingsAccount

    init() {
        state = LocalStore.load(SavingsAccount.self, from: storeName) ?? SavingsAccount(
            name: "Flexible Saver",
            sortCode: "60-00-01",
            accountNumber: "48213907",
            balance: 6_420,
            interestRate: 1.25,
            activity: [
                SavingsActivity(date: .now.addingTimeInterval(-86_400 * 12), title: "Transfer from current account", amount: 250, reference: "MONTHLY SAVE")
            ]
        )
    }

    func account() async throws -> SavingsAccount {
        await simulateLatency(300)
        return state
    }

    func withdrawStake(_ amount: Double, reference: String) async throws -> SavingsAccount {
        await simulateLatency()
        guard state.balance >= amount else { throw ServiceError.insufficientFunds }
        state.balance -= amount
        state.activity.insert(SavingsActivity(date: .now, title: "Arena stake held", amount: -amount, reference: reference), at: 0)
        persist()
        return state
    }

    func depositPayout(_ amount: Double, reference: String) async throws -> SavingsAccount {
        await simulateLatency()
        state.balance += amount
        state.activity.insert(SavingsActivity(date: .now, title: "Arena prize pot", amount: amount, reference: reference), at: 0)
        persist()
        return state
    }

    func topUp(_ amount: Double) async throws -> SavingsAccount {
        await simulateLatency()
        state.balance += amount
        state.activity.insert(SavingsActivity(date: .now, title: "Transfer from current account", amount: amount, reference: "TOP UP"), at: 0)
        persist()
        return state
    }

    private func persist() { LocalStore.save(state, to: storeName) }
}

/// Mock Free / Pro plan. Any 16-digit card number starts the 7-day trial,
/// except the standard "declined" test number 4000 0000 0000 0002.
final class MockSubscriptionService: SubscriptionServicing {
    private let planKey = "nova.plan"
    private let trialKey = "nova.trialEndsAt"

    var plan: Plan {
        Plan(rawValue: UserDefaults.standard.string(forKey: planKey) ?? "") ?? .free
    }

    var trialEndsAt: Date? {
        UserDefaults.standard.object(forKey: trialKey) as? Date
    }

    func startProTrial(cardNumber: String, expiry: String, cvc: String) async throws -> Plan {
        await simulateLatency(1_200)
        let digits = cardNumber.filter(\.isNumber)
        guard digits.count == 16, expiry.count >= 4, cvc.count >= 3 else { throw ServiceError.paymentDeclined }
        if digits == "4000000000000002" { throw ServiceError.paymentDeclined }
        UserDefaults.standard.set(Plan.pro.rawValue, forKey: planKey)
        UserDefaults.standard.set(Calendar.current.date(byAdding: .day, value: 7, to: .now), forKey: trialKey)
        return .pro
    }

    func cancel() async -> Plan {
        await simulateLatency()
        UserDefaults.standard.set(Plan.free.rawValue, forKey: planKey)
        UserDefaults.standard.removeObject(forKey: trialKey)
        return .free
    }
}
