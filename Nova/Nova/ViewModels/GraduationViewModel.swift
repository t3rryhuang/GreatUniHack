import Foundation
import Observation
import SwiftUI

/// What goes on the one-page Readiness Report.
struct ReadinessReportData: Sendable {
    let name: String
    let date: Date
    let score: Int
    let rank: ReadinessRank
    let onTimeMonths: Int
    let onTimePayments: Int
    let longestStreak: Int
    let bufferWeeks: Double
    let loansRepaid: Int
    let stats: [StatScore]
}

@Observable
final class GraduationViewModel {
    var consent = false
    private(set) var pdfURL: URL?

    func daysToEighteen(model: AppModel) -> Int? {
        guard let birthday = model.eighteenthBirthday else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: birthday).day ?? 0)
    }

    func items(model: AppModel) -> [(GraduationItem, Bool)] {
        GraduationItem.allCases.map { item in
            (item, ReadinessRules.isDone(item, snapshot: model.readiness, progress: model.readinessProgress,
                                         summary: model.summary, savings: model.savingsAccount?.balance ?? 0))
        }
    }

    func reportData(model: AppModel) -> ReadinessReportData? {
        guard let snapshot = model.readiness else { return nil }
        let weekly = model.summary.avgMonthly / 4.345
        return ReadinessReportData(
            name: model.user?.name ?? "",
            date: .now,
            score: snapshot.score.total,
            rank: snapshot.score.rank,
            onTimeMonths: snapshot.onTimeMonths,
            onTimePayments: snapshot.onTimePayments,
            longestStreak: snapshot.longestStreak,
            bufferWeeks: weekly > 0 ? (model.savingsAccount?.balance ?? 0) / weekly : 0,
            loansRepaid: model.family.repaidLoans.count,
            stats: snapshot.score.stats
        )
    }

    /// Renders the report page to a one-page PDF in the temporary folder.
    func renderPDF(_ data: ReadinessReportData) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Readiness Report.pdf")
        let renderer = ImageRenderer(content: ReadinessReportPage(data: data).frame(width: 400).environment(\.colorScheme, .light))
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
        pdfURL = url
    }
}
