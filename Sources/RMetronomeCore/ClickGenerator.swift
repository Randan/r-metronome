import AVFoundation
import Foundation

public final class ClickGenerator {
    public struct Buffers {
        public let accent: AVAudioPCMBuffer
        public let normal: AVAudioPCMBuffer
        public let subdivision: AVAudioPCMBuffer
        public let polyrhythm: AVAudioPCMBuffer
    }

    public let format: AVAudioFormat
    public let buffers: Buffers

    public init(sampleRate: Double, channelCount: AVAudioChannelCount = 2) {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            fatalError("Unable to create click audio format")
        }

        self.format = format
        self.buffers = Buffers(
            accent: Self.makeClick(format: format, frequency: 1600, duration: 0.020, gain: 0.9),
            normal: Self.makeClick(format: format, frequency: 1100, duration: 0.016, gain: 0.65),
            subdivision: Self.makeClick(format: format, frequency: 850, duration: 0.010, gain: 0.45),
            polyrhythm: Self.makeClick(format: format, frequency: 600, duration: 0.018, gain: 0.65)
        )
    }

    public func buffer(for layer: ClickEvent.Layer) -> AVAudioPCMBuffer {
        switch layer {
        case .accent:
            buffers.accent
        case .normal:
            buffers.normal
        case .subdivision:
            buffers.subdivision
        case .polyrhythm:
            buffers.polyrhythm
        }
    }

    private static func makeClick(
        format: AVAudioFormat,
        frequency: Double,
        duration: Double,
        gain: Float
    ) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount((format.sampleRate * duration).rounded(.up))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            fatalError("Unable to allocate click buffer")
        }
        buffer.frameLength = frameCount

        let channels = Int(format.channelCount)
        let frames = Int(frameCount)
        for channel in 0..<channels {
            guard let channelData = buffer.floatChannelData?[channel] else { continue }
            for frame in 0..<frames {
                let t = Double(frame) / format.sampleRate
                let envelope = exp(-t * 180.0)
                channelData[frame] = gain * Float(sin(2.0 * .pi * frequency * t) * envelope)
            }
        }

        return buffer
    }
}
