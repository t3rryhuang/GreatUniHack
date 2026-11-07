import Foundation

extension Double {
    /// Pounds with pence, for example "£12.40".
    nonisolated var gbp: String {
        formatted(.currency(code: "GBP").locale(Locale(identifier: "en_GB")))
    }

    /// Whole pounds, for example "£1,240".
    nonisolated var gbpWhole: String {
        formatted(.currency(code: "GBP").locale(Locale(identifier: "en_GB")).precision(.fractionLength(0)))
    }

    /// "72%" from 0.72.
    nonisolated var percent: String {
        formatted(.percent.precision(.fractionLength(0)))
    }
}
