// Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.

import AVFoundation
import RimwardCore

/// Plays the synthesized effects through a small pool of player nodes.
final class SoundEngine {
    private let engine = AVAudioEngine()
    private let format: AVAudioFormat?
    private var voices: [AVAudioPlayerNode] = []
    private let fireVoice = AVAudioPlayerNode()
    private var buffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var nextVoice = 0
    private var ready = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        guard let format else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        for _ in 0..<6 {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
            voices.append(voice)
        }
        engine.attach(fireVoice)
        engine.connect(fireVoice, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.7

        for effect in SoundEffect.allCases {
            let samples = SoundSynthesis.samples(for: effect, sampleRate: format.sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
                  let channel = buffer.floatChannelData?[0] else { continue }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            for (i, sample) in samples.enumerated() { channel[i] = sample }
            buffers[effect] = buffer
        }
        ready = (try? engine.start()) != nil
    }

    func play(_ effect: SoundEffect) {
        guard ready, let buffer = buffers[effect] else { return }
        if !engine.isRunning {
            guard (try? engine.start()) != nil else { return }
        }
        let voice: AVAudioPlayerNode
        if effect == .fire {
            voice = fireVoice
        } else {
            voice = voices[nextVoice]
            nextVoice = (nextVoice + 1) % voices.count
        }
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.isPlaying { voice.play() }
    }
}
