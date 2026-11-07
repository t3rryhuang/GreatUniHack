import Foundation
import Observation

@Observable
final class ChatViewModel {
    /// The original app kept the last 20 messages as context.
    static let historyLimit = 20
    static let starters = ["Where does most of my money go?", "Can I afford a £200 weekend away?",
                           "How much will I spend this week?", "How long would my savings last?"]

    var draft = ""
    var speakReplies = false
    private(set) var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Hi, I'm Nova. I can see your spending patterns and predictions. What would you like to know?")
    ]
    private(set) var isTyping = false
    private(set) var isListening = false

    func send(model: AppModel, text: String? = nil) async {
        let message = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isTyping else { return }
        draft = ""
        messages.append(ChatMessage(role: .user, text: message))
        isTyping = true
        defer { isTyping = false }
        do {
            let history = Array(messages.suffix(Self.historyLimit))
            let reply = try await model.services.chat.reply(to: message, history: history, summary: model.summary)
            messages.append(ChatMessage(role: .assistant, text: reply))
            if speakReplies { model.services.voice.speak(reply) }
        } catch {
            messages.append(ChatMessage(role: .assistant, text: "Sorry, I couldn't answer that just now. Please try again."))
        }
    }

    func listen(model: AppModel) async {
        isListening = true
        let text = try? await model.services.voice.transcribe()
        isListening = false
        if let text { await send(model: model, text: text) }
    }
}
