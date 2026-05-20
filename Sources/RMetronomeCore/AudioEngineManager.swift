import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

public final class AudioEngineManager {
    public enum EngineError: Error {
        case outputFormatUnavailable
        case outputDeviceUnavailable(OSStatus)
    }

    public let engine: AVAudioEngine
    public let accentNode: AVAudioPlayerNode
    public let normalNode: AVAudioPlayerNode
    public let subdivisionNode: AVAudioPlayerNode
    public let polyrhythmNode: AVAudioPlayerNode

    private let clickGenerator: ClickGenerator
    private let silenceBuffer: AVAudioPCMBuffer

    private let outputSelection: AudioOutputSelection

    public init(
        sampleRate: Double = 48_000,
        layerGains: LayerGains = .default,
        outputSelection: AudioOutputSelection = .systemDefault
    ) {
        self.engine = AVAudioEngine()
        self.accentNode = AVAudioPlayerNode()
        self.normalNode = AVAudioPlayerNode()
        self.subdivisionNode = AVAudioPlayerNode()
        self.polyrhythmNode = AVAudioPlayerNode()
        self.clickGenerator = ClickGenerator(sampleRate: sampleRate)
        self.silenceBuffer = Self.makeSilenceBuffer(format: clickGenerator.format)
        self.outputSelection = outputSelection
        configureGraph()
        updateGains(layerGains)
    }

    public func start() throws {
        try applyOutputSelection()
        if !engine.isRunning {
            try engine.start()
        }
        [accentNode, normalNode, subdivisionNode, polyrhythmNode].forEach { node in
            if !node.isPlaying {
                node.play()
            }
        }
    }

    public func stop() {
        [accentNode, normalNode, subdivisionNode, polyrhythmNode].forEach { node in
            node.stop()
            node.reset()
        }
        engine.stop()
    }

    public func schedule(_ events: [ClickEvent]) {
        for event in events {
            let node = playerNode(for: event.layer)
            let buffer = clickGenerator.buffer(for: event.layer)
            let time = AVAudioTime(sampleTime: event.sampleTime, atRate: clickGenerator.format.sampleRate)
            node.scheduleBuffer(buffer, at: time, options: [])
        }
    }

    public func reschedule(_ events: [ClickEvent], interruptingAt sampleTime: Int64) {
        let groupedEvents = Dictionary(grouping: events, by: \.layer)
        let interruptTime = AVAudioTime(sampleTime: sampleTime, atRate: clickGenerator.format.sampleRate)

        ClickEvent.Layer.allCases.forEach { layer in
            let node = playerNode(for: layer)
            node.scheduleBuffer(silenceBuffer, at: interruptTime, options: .interrupts)

            for event in groupedEvents[layer] ?? [] {
                schedule(event, on: node, options: [])
            }
        }
    }

    public func currentSampleTime() -> Int64? {
        guard
            let nodeTime = accentNode.lastRenderTime,
            let playerTime = accentNode.playerTime(forNodeTime: nodeTime)
        else {
            return nil
        }
        return playerTime.sampleTime
    }

    public func updateGains(_ gains: LayerGains) {
        accentNode.volume = gains.accent
        normalNode.volume = gains.normal
        subdivisionNode.volume = gains.subdivision
        polyrhythmNode.volume = gains.polyrhythm
    }

    private func configureGraph() {
        let mixer = engine.mainMixerNode
        [accentNode, normalNode, subdivisionNode, polyrhythmNode].forEach { node in
            engine.attach(node)
            engine.connect(node, to: mixer, format: clickGenerator.format)
        }
    }

    private func schedule(
        _ event: ClickEvent,
        on node: AVAudioPlayerNode,
        options: AVAudioPlayerNodeBufferOptions
    ) {
        let buffer = clickGenerator.buffer(for: event.layer)
        let time = AVAudioTime(sampleTime: event.sampleTime, atRate: clickGenerator.format.sampleRate)
        node.scheduleBuffer(buffer, at: time, options: options)
    }

    private func playerNode(for layer: ClickEvent.Layer) -> AVAudioPlayerNode {
        switch layer {
        case .accent:
            accentNode
        case .normal:
            normalNode
        case .subdivision:
            subdivisionNode
        case .polyrhythm:
            polyrhythmNode
        }
    }

    private static func makeSilenceBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCapacity: AVAudioFrameCount = 64
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            preconditionFailure("Unable to allocate silence buffer")
        }
        buffer.frameLength = frameCapacity
        return buffer
    }

    private func applyOutputSelection() throws {
        engine.outputNode.auAudioUnit.channelMap = [
            NSNumber(value: Int32(outputSelection.channelPair.left)),
            NSNumber(value: Int32(outputSelection.channelPair.right))
        ]

        guard let deviceID = outputSelection.deviceID else { return }

        var selectedDeviceID = deviceID
        let status = AudioUnitSetProperty(
            engine.outputNode.audioUnit!,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &selectedDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw EngineError.outputDeviceUnavailable(status)
        }
    }
}
