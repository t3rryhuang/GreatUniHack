import AVFoundation
import SwiftUI
import UIKit

extension Notification.Name {
    /// Posted when the device is shaken (Device > Shake in the Simulator).
    static let deviceDidShake = Notification.Name("NovaDeviceDidShake")
}

extension UIWindow {
    /// Standard shake detection. Screens listen only while they're visible.
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { NotificationCenter.default.post(name: .deviceDidShake, object: nil) }
        super.motionEnded(motion, with: event)
    }
}

/// Coin sounds synthesised in code with AVAudioEngine (no sound files are downloaded).
/// The number and loudness of clinks follow the tier (progress to the teen's own goal);
/// tier 4 adds a short celebration chime. Uses the ambient category, so the silent switch mutes it.
final class CoinSoundPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    private var buffers: [Int: AVAudioPCMBuffer] = [:]

    init() {
        engine.attach(player)
        if let format { engine.connect(player, to: engine.mainMixerNode, format: format) }
    }

    func play(tier: Int) {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        if !engine.isRunning { try? engine.start() }
        guard let buffer = buffer(for: tier) else { return }
        player.stop()
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
    }

    func stop() {
        player.stop()
        engine.stop()
    }

    private func buffer(for tier: Int) -> AVAudioPCMBuffer? {
        if let cached = buffers[tier] { return cached }
        guard let format else { return nil }
        let rate = format.sampleRate
        let clinks = [2, 4, 7, 12, 14][min(max(tier, 0), 4)]
        let loudness = [0.35, 0.5, 0.65, 0.8, 0.8][min(max(tier, 0), 4)]
        let spacing = tier >= 3 ? 0.055 : 0.11
        let duration = Double(clinks) * spacing + 0.35 + (tier == 4 ? 0.9 : 0)
        let frames = AVAudioFrameCount(duration * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) { data[i] = 0 }

        var rng = MockDataFactory.SeededGenerator(seed: UInt64(42 + tier))
        func tone(start: Double, frequency: Double, amplitude: Double, decay: Double, length: Double) {
            let first = Int(start * rate)
            let count = Int(length * rate)
            for n in 0..<count where first + n < Int(frames) {
                let t = Double(n) / rate
                let envelope = exp(-t * decay) * min(1, t * 2_000)
                let sample = sin(2 * .pi * frequency * t) + 0.45 * sin(2 * .pi * frequency * 2.76 * t) + 0.2 * sin(2 * .pi * frequency * 5.4 * t)
                data[first + n] += Float(sample * envelope * amplitude)
            }
        }
        // Metal clinks: a bright partial set with a fast decay and a little timing jitter.
        for index in 0..<clinks {
            let start = Double(index) * spacing + Double.random(in: 0...0.03, using: &rng)
            tone(start: start, frequency: Double.random(in: 2_300...4_200, using: &rng),
                 amplitude: loudness * Double.random(in: 0.18...0.3, using: &rng), decay: 38, length: 0.25)
        }
        // Goal reached: a rising major chord.
        if tier == 4 {
            let base = Double(clinks) * spacing + 0.1
            for (index, frequency) in [1_046.5, 1_318.5, 1_568.0, 2_093.0].enumerated() {
                tone(start: base + Double(index) * 0.12, frequency: frequency, amplitude: 0.18, decay: 4, length: 0.8)
            }
        }
        for i in 0..<Int(frames) { data[i] = max(-0.95, min(0.95, data[i])) }
        buffers[tier] = buffer
        return buffer
    }
}

/// Taps that scale with the same tier as the sound.
enum PiggyHaptics {
    static func play(tier: Int) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = tier <= 0 ? .light : tier == 1 ? .light : tier == 2 ? .medium : .heavy
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        let taps = [2, 3, 5, 7, 7][min(max(tier, 0), 4)]
        Task { @MainActor in
            for index in 0..<taps {
                generator.impactOccurred(intensity: min(1, 0.4 + Double(tier) * 0.15 + Double(index % 2) * 0.1))
                try? await Task.sleep(for: .milliseconds(80))
            }
            if tier == 4 { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
    }
}
