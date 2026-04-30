import AVFoundation
import Foundation

public final class AudioEngineManager {
    public enum EngineError: Error {
        case outputFormatUnavailable
    }

    public let engine: AVAudioEngine
    public let accentNode: AVAudioPlayerNode
    public let normalNode: AVAudioPlayerNode
    public let subdivisionNode: AVAudioPlayerNode

    private let clickGenerator: ClickGenerator

    public init(sampleRate: Double = 48_000, layerGains: LayerGains = .default) {
        self.engine = AVAudioEngine()
        self.accentNode = AVAudioPlayerNode()
        self.normalNode = AVAudioPlayerNode()
        self.subdivisionNode = AVAudioPlayerNode()
        self.clickGenerator = ClickGenerator(sampleRate: sampleRate)
        configureGraph()
        updateGains(layerGains)
    }

    public func start() throws {
        if !engine.isRunning {
            try engine.start()
        }
        [accentNode, normalNode, subdivisionNode].forEach { node in
            if !node.isPlaying {
                node.play()
            }
        }
    }

    public func stop() {
        [accentNode, normalNode, subdivisionNode].forEach { node in
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
    }

    private func configureGraph() {
        let mixer = engine.mainMixerNode
        [accentNode, normalNode, subdivisionNode].forEach { node in
            engine.attach(node)
            engine.connect(node, to: mixer, format: clickGenerator.format)
        }
    }

    private func playerNode(for layer: ClickEvent.Layer) -> AVAudioPlayerNode {
        switch layer {
        case .accent:
            accentNode
        case .normal:
            normalNode
        case .subdivision:
            subdivisionNode
        }
    }
}
