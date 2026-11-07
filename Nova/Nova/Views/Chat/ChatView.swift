import SwiftUI

/// "Ask Nova" chat with voice input and read-aloud replies. Ported from chat.tsx.
struct ChatView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ChatViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message).id(message.id)
                        }
                        if viewModel.isTyping {
                            TypingIndicator().frame(maxWidth: .infinity, alignment: .leading).id("typing")
                        }
                        if viewModel.messages.count == 1 {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Try asking").overline()
                                ForEach(ChatViewModel.starters, id: \.self) { starter in
                                    Button(starter) { Task { await viewModel.send(model: model, text: starter) } }
                                        .buttonStyle(NovaChipStyle())
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Spacing.md)
                        }
                    }
                    .padding(Spacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) {
                    withAnimation { proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom) }
                }
            }
            .background(NovaColor.page)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: Spacing.xs) {
                    if viewModel.isListening {
                        Text("Listening… pause or tap the microphone to send")
                            .font(.novaCaption).foregroundStyle(NovaColor.body)
                    } else if let error = viewModel.voiceError {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.novaCaption).foregroundStyle(NovaColor.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.md)
                    }
                    inputBar
                }
            }
            .navigationTitle("Ask Nova")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        model.services.voice.stopSpeaking()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $viewModel.speakReplies) {
                        Image(systemName: viewModel.speakReplies ? "speaker.wave.2.fill" : "speaker.slash")
                    }
                    .toggleStyle(.button)
                    .accessibilityLabel("Read replies aloud")
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: Spacing.xs) {
            Button {
                Task { await viewModel.listen(model: model) }
            } label: {
                Image(systemName: viewModel.isListening ? "waveform" : "mic.fill")
                    .symbolEffect(.variableColor.iterative, isActive: viewModel.isListening)
                    .font(.headline)
                    .foregroundStyle(viewModel.isListening ? NovaColor.onAction : NovaColor.action)
                    .frame(width: 44, height: 44)
                    .background(viewModel.isListening ? NovaColor.action : NovaColor.lilac, in: Circle())
            }
            .accessibilityLabel(viewModel.isListening ? "Stop listening" : "Ask by voice")
            .accessibilityHint(viewModel.isListening ? "Stops recording and sends your question" : "Records your question. Stops when you pause.")
            .disabled(viewModel.isTyping)

            TextField("Ask about your money", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(NovaColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(NovaColor.hairline))

            Button {
                Task { await viewModel.send(model: model) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(NovaColor.onAction)
                    .frame(width: 44, height: 44)
                    .background(NovaColor.action, in: Circle())
            }
            .accessibilityLabel("Send")
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isTyping)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(.bar)
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        let isUser = message.role == .user
        HStack {
            if isUser { Spacer(minLength: 48) }
            Text(message.text)
                .font(.novaBody)
                .foregroundStyle(isUser ? NovaColor.onAction : NovaColor.heading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isUser ? NovaColor.action : NovaColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    if !isUser { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NovaColor.hairline) }
                }
                .textSelection(.enabled)
            if !isUser { Spacer(minLength: 48) }
        }
        .accessibilityLabel("\(isUser ? "You" : "Nova"): \(message.text)")
    }
}

private struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.3, paused: reduceMotion)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.3) % 3
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(NovaColor.action.opacity(index == step ? 1 : 0.35))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 2)
            .background(NovaColor.card, in: Capsule())
        }
        .accessibilityLabel("Nova is typing")
    }
}
