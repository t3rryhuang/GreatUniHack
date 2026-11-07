import AVFoundation
import Foundation
import Observation

/// Mock "Ask Nova" assistant. Answers common money questions from the user's summary.
/// Replace with the real LLM backend behind `ChatServicing`.
final class MockChatService: ChatServicing {
    func reply(to message: String, history: [ChatMessage], summary: FinancialSummary) async throws -> String {
        await simulateLatency(900)
        let q = message.lowercased()
        let top = summary.topCategories.first { ![.rent, .utilities, .transfer].contains($0.category) }
        let months = max(1, summary.dataRangeMonths)

        if q.contains("hello") || q.contains("hi ") || q == "hi" || q.contains("hey") {
            return "Hi! I'm Nova. Ask me about your spending, your savings or what to expect this week."
        }
        if q.contains("afford") {
            let spare = max(0, summary.monthlyIncome - summary.avgMonthly)
            return "After your usual spending you have about \(spare.gbpWhole) spare each month. If the purchase is less than that, you can afford it without touching your savings."
        }
        if q.contains("save") || q.contains("saving") {
            return "You're saving about \(Int(summary.savingsRate))% of your income, with \(summary.savings.gbpWhole) in your Flexible Saver. A standing order of £50 more on payday would add \((50 * 12.0).gbpWhole) a year."
        }
        if q.contains("week") || q.contains("predict") || q.contains("today") {
            return "Based on your habits, I expect about \((summary.avgDaily * 7).gbpWhole) of spending this week. Your most likely spends are coffee on weekday mornings and dining out at the weekend."
        }
        if q.contains("most") || q.contains("biggest") || q.contains("where") {
            if let top {
                return "Apart from bills, your biggest category is \(top.category.rawValue.lowercased()) at about \((top.amount / months).gbpWhole) a month (\(top.share.percent) of your spending)."
            }
        }
        if q.contains("runway") || q.contains("quit") || q.contains("job") {
            return "With \(summary.savings.gbpWhole) saved, you could cover \(String(format: "%.1f", summary.runwayMonths)) months of your normal spending without income."
        }
        if q.contains("coffee") {
            return "Coffee is a small daily spend that adds up. Cutting one coffee a day saves around £90 a month."
        }
        return "You spend about \(summary.avgMonthly.gbpWhole) a month and earn about \(summary.monthlyIncome.gbpWhole). \(top.map { "Your top discretionary category is \($0.category.rawValue.lowercased())." } ?? "") Ask me what you can afford, where your money goes, or how long your savings would last."
    }
}

/// Text to speech with the built-in iOS voices (replaces ElevenLabs).
/// Speech to text is mocked until the backend's transcription endpoint is connected.
@Observable
final class SystemVoiceService: NSObject, VoiceServicing, AVSpeechSynthesizerDelegate {
    private(set) var isSpeaking = false
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.98
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    func transcribe() async throws -> String {
        await simulateLatency(1_800)
        return ["How much did I spend on coffee this month?",
                "Can I afford a £200 weekend away?",
                "What's my biggest spending category?"].randomElement() ?? "How am I doing this week?"
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
