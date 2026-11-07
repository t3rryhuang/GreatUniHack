import AVFoundation
import Foundation
import Observation

/// "Ask Nova" answered by Claude on the backend, using the user's real summary.
/// Falls back to the on-device answers if the backend can't be reached.
final class RemoteChatService: ChatServicing {
    private let client: BackendClient
    private let fallback = MockChatService()

    init(client: BackendClient) { self.client = client }

    func reply(to message: String, history: [ChatMessage], summary: FinancialSummary, stage: LifeStage) async throws -> String {
        struct Turn: Encodable { let role: String; let content: String }
        struct Body: Encodable { let message: String; let history: [Turn]; let summary: WireSummary; let stage: String }
        struct Wire: Decodable { let reply: String }
        let turns = history.suffix(20).map { Turn(role: $0.role == .user ? "user" : "assistant", content: $0.text) }
        do {
            let r: Wire = try await client.send("POST", "nova/chat", body: Body(message: message, history: turns, summary: WireSummary(summary), stage: stage.rawValue))
            return r.reply
        } catch {
            return try await fallback.reply(to: message, history: history, summary: summary, stage: stage)
        }
    }
}

/// Read-aloud with the ElevenLabs voice from the backend (`/nova/tts`), like the
/// original app. Falls back to the built-in iOS voice if the request fails.
@Observable
final class ElevenLabsVoiceService: NSObject, VoiceServicing, AVAudioPlayerDelegate {
    private(set) var isSpeaking = false
    @ObservationIgnored private let client: BackendClient
    @ObservationIgnored private let fallback = SystemVoiceService()
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var cache: [String: Data] = [:]
    @ObservationIgnored private let recorder = VoiceRecorder()

    init(client: BackendClient) {
        self.client = client
        super.init()
    }

    func speak(_ text: String) {
        stopSpeaking()
        isSpeaking = true
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let audio: Data
                if let cached = cache[text] {
                    audio = cached
                } else {
                    audio = try await client.data("POST", "nova/tts", body: ["text": text])
                    cache[text] = audio
                }
                try Task.checkCancellation()
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                try? AVAudioSession.sharedInstance().setActive(true)
                let player = try AVAudioPlayer(data: audio)
                player.delegate = self
                self.player = player
                if !player.play() { throw ServiceError.network("Playback failed") }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                isSpeaking = false
                fallback.speak(text)
                isSpeaking = true
                watchFallback()
            }
        }
    }

    func stopSpeaking() {
        task?.cancel()
        task = nil
        player?.stop()
        player = nil
        fallback.stopSpeaking()
        isSpeaking = false
    }

    /// Records the question on-device, then transcribes it with ElevenLabs Scribe on the backend.
    func transcribe() async throws -> String {
        stopSpeaking()
        let audioURL = try await recorder.record()
        defer { try? FileManager.default.removeItem(at: audioURL) }
        struct Wire: Decodable { let text: String }
        let result: Wire = try await client.upload("nova/transcribe", fileURL: audioURL, mimeType: "audio/mp4")
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw VoiceRecorder.RecordingError.nothingHeard }
        return text
    }

    func stopListening() {
        recorder.stop()
    }

    /// Mirror the system voice's state while it is speaking for us.
    private func watchFallback() {
        task = Task { [weak self] in
            while let self, !Task.isCancelled, self.fallback.isSpeaking {
                try? await Task.sleep(for: .milliseconds(250))
            }
            self?.isSpeaking = false
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
