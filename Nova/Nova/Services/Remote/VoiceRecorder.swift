import AVFoundation
import Foundation

/// Records one spoken question to a temporary .m4a file.
/// Stops by itself after a pause in speech, after `maxDuration`, or when `stop()` is called.
final class VoiceRecorder {
    enum RecordingError: LocalizedError {
        case permissionDenied
        case nothingHeard
        case failedToStart

        var errorDescription: String? {
            switch self {
            case .permissionDenied: "Nova needs microphone access. Turn it on in Settings > Nova."
            case .nothingHeard: "I didn't catch that. Tap the microphone and try again."
            case .failedToStart: "The microphone couldn't start. Please try again."
            }
        }
    }

    var maxDuration: TimeInterval = 20
    /// How long of a pause after speaking ends the recording.
    var silenceToStop: TimeInterval = 1.5
    /// Give up if nobody speaks within this time.
    var noSpeechTimeout: TimeInterval = 7
    /// Average power (dBFS) above which we treat the input as speech.
    var speechThreshold: Float = -38

    private var recorder: AVAudioRecorder?
    private var stopRequested = false

    var isRecording: Bool { recorder?.isRecording ?? false }

    func stop() { stopRequested = true }

    /// Records until the user stops talking and returns the audio file URL.
    func record() async throws -> URL {
        guard await AVAudioApplication.requestRecordPermission() else { throw RecordingError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
        defer { try? session.setActive(false, options: .notifyOthersOnDeactivation) }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nova-voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        self.recorder = recorder
        stopRequested = false
        guard recorder.record() else { throw RecordingError.failedToStart }

        let start = Date.now
        var heardSpeech = false
        var lastSpeech = start
        while !Task.isCancelled && !stopRequested {
            try? await Task.sleep(for: .milliseconds(100))
            recorder.updateMeters()
            let now = Date.now
            if recorder.averagePower(forChannel: 0) > speechThreshold {
                heardSpeech = true
                lastSpeech = now
            }
            if heardSpeech && now.timeIntervalSince(lastSpeech) >= silenceToStop { break }
            if !heardSpeech && now.timeIntervalSince(start) >= noSpeechTimeout { break }
            if now.timeIntervalSince(start) >= maxDuration { break }
        }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil

        if Task.isCancelled {
            try? FileManager.default.removeItem(at: url)
            throw CancellationError()
        }
        // A manual stop counts even if the level meter never crossed the threshold (quiet voices).
        guard (heardSpeech || stopRequested), duration > 0.4 else {
            try? FileManager.default.removeItem(at: url)
            throw RecordingError.nothingHeard
        }
        return url
    }
}
