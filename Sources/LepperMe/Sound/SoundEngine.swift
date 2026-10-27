import AVFoundation

/// Soft, synthesized UI sounds (bell-like additive synthesis + hall reverb).
/// No audio files to license or ship. The engine only runs while a sound plays, so the
/// output device isn't kept busy in between.
@MainActor
final class SoundEngine {
    enum Cue: CaseIterable {
        case preWarning
        case breakStart
        case breakEnd
        case skip
        case snooze
        case posture
        case welcomeBack
    }

    var volume: Float = 0.7

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var stopTask: Task<Void, Never>?
    private var isWired = false

    /// Wire the graph on first use, so launching never touches the audio hardware.
    private func wireIfNeeded() {
        guard !isWired else { return }
        isWired = true
        reverb.loadFactoryPreset(.largeHall2)
        reverb.wetDryMix = 32
        engine.attach(player)
        engine.attach(reverb)
        engine.connect(player, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
    }

    func play(_ cue: Cue) {
        guard volume > 0 else { return }
        wireIfNeeded()
        let buffer = buffers[cue] ?? render(cue)
        buffers[cue] = buffer

        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            NSLog("LepperMe: audio engine could not start: \(error)")
            return
        }
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: [])
        if !player.isPlaying { player.play() }

        // Let the reverb tail ring out, then release the audio device.
        stopTask?.cancel()
        let seconds = Double(buffer.frameLength) / format.sampleRate + 2.5
        stopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.player.stop()
            self.engine.stop()
        }
    }

    // MARK: - Synthesis

    private struct Note {
        let frequency: Double
        let start: Double
        let duration: Double
        let amplitude: Double
    }

    private func notes(for cue: Cue) -> [Note] {
        switch cue {
        case .breakStart:
            // Fmaj7, gently rolled: calm and warm.
            return [
                Note(frequency: 349.23, start: 0.00, duration: 2.6, amplitude: 0.16),
                Note(frequency: 440.00, start: 0.09, duration: 2.5, amplitude: 0.14),
                Note(frequency: 523.25, start: 0.18, duration: 2.4, amplitude: 0.13),
                Note(frequency: 659.25, start: 0.27, duration: 2.3, amplitude: 0.12)
            ]
        case .breakEnd:
            // Rising D major arpeggio: bright resolution.
            return [
                Note(frequency: 587.33, start: 0.00, duration: 1.8, amplitude: 0.13),
                Note(frequency: 739.99, start: 0.11, duration: 1.8, amplitude: 0.12),
                Note(frequency: 880.00, start: 0.22, duration: 1.9, amplitude: 0.12),
                Note(frequency: 1174.66, start: 0.33, duration: 2.2, amplitude: 0.11)
            ]
        case .preWarning:
            // Two quiet glass taps.
            return [
                Note(frequency: 1318.51, start: 0.00, duration: 0.9, amplitude: 0.09),
                Note(frequency: 1975.53, start: 0.08, duration: 0.8, amplitude: 0.05)
            ]
        case .skip:
            return [
                Note(frequency: 880.00, start: 0.00, duration: 0.6, amplitude: 0.09),
                Note(frequency: 659.25, start: 0.08, duration: 0.8, amplitude: 0.09)
            ]
        case .posture:
            // Quick upward lift.
            return [
                Note(frequency: 659.25, start: 0.00, duration: 0.7, amplitude: 0.08),
                Note(frequency: 987.77, start: 0.09, duration: 0.9, amplitude: 0.08)
            ]
        case .welcomeBack:
            // Soft, friendly "I'm here again": rising fifth.
            return [
                Note(frequency: 523.25, start: 0.00, duration: 1.0, amplitude: 0.08),
                Note(frequency: 783.99, start: 0.12, duration: 1.2, amplitude: 0.08)
            ]
        case .snooze:
            return [
                Note(frequency: 783.99, start: 0.00, duration: 0.7, amplitude: 0.09),
                Note(frequency: 587.33, start: 0.10, duration: 0.9, amplitude: 0.09)
            ]
        }
    }

    /// Bell-ish tone: a few partials with their own decay, plus a slightly detuned copy for shimmer.
    private func render(_ cue: Cue) -> AVAudioPCMBuffer {
        let notes = notes(for: cue)
        let sampleRate = format.sampleRate
        let length = (notes.map { $0.start + $0.duration }.max() ?? 1) + 0.1
        let frameCount = AVAudioFrameCount(length * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let left = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]
        for i in 0..<Int(frameCount) { left[i] = 0; right[i] = 0 }

        // (frequency ratio, amplitude, decay factor)
        let partials: [(Double, Double, Double)] = [
            (1.0, 1.00, 1.0),
            (2.0, 0.32, 1.8),
            (3.0, 0.10, 2.6),
            (4.07, 0.05, 3.5) // slightly inharmonic: the "glass" in the bell
        ]
        let attack = 0.006

        for (noteIndex, note) in notes.enumerated() {
            // Spread the notes a little across the stereo field.
            let pan = notes.count > 1 ? (Double(noteIndex) / Double(notes.count - 1) - 0.5) * 0.6 : 0
            let gainL = Float(cos((pan + 1) * .pi / 4))
            let gainR = Float(sin((pan + 1) * .pi / 4))
            let startFrame = Int(note.start * sampleRate)
            let frames = Int(note.duration * sampleRate)
            let tau = note.duration / 4.5
            for n in 0..<frames {
                let index = startFrame + n
                guard index < Int(frameCount) else { break }
                let t = Double(n) / sampleRate
                let attackGain = min(1, t / attack)
                // Fade the last 80 ms to zero so nothing clicks.
                let release = min(1, (note.duration - t) / 0.08)
                var sample = 0.0
                for (ratio, amp, decay) in partials {
                    let f = note.frequency * ratio
                    let env = exp(-t * decay / tau)
                    sample += amp * env * (sin(2 * .pi * f * t) + 0.5 * sin(2 * .pi * f * 1.0035 * t))
                }
                let value = Float(sample * note.amplitude * attackGain * max(0, release))
                left[index] += value * gainL
                right[index] += value * gainR
            }
        }

        // Soft clip, just in case notes stack up.
        for i in 0..<Int(frameCount) {
            left[i] = tanhf(left[i] * 1.2) / 1.2
            right[i] = tanhf(right[i] * 1.2) / 1.2
        }
        return buffer
    }
}
