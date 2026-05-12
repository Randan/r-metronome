import Foundation

public final class MetronomeTransport: @unchecked Sendable {
    public struct Configuration: Equatable, Sendable {
        public var sampleRate: Double
        public var lookaheadSeconds: Double
        public var refillIntervalSeconds: Double

        public init(
            sampleRate: Double = 48_000,
            lookaheadSeconds: Double = 1.5,
            refillIntervalSeconds: Double = 0.25
        ) {
            precondition(sampleRate > 0, "sampleRate must be greater than zero")
            precondition(lookaheadSeconds > 0, "lookaheadSeconds must be greater than zero")
            precondition(refillIntervalSeconds > 0, "refillIntervalSeconds must be greater than zero")
            self.sampleRate = sampleRate
            self.lookaheadSeconds = lookaheadSeconds
            self.refillIntervalSeconds = refillIntervalSeconds
        }
    }

    private let configuration: Configuration
    private let lock = NSLock()
    private var audioEngine: AudioEngineManager?
    private var scheduler: MetronomeScheduler?
    private var scheduledThroughSample: Int64 = -1
    private var isRunning = false
    private var plannerThread: Thread?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public func start(state: MetronomeState) throws {
        stop()

        let engine = AudioEngineManager(
            sampleRate: configuration.sampleRate,
            layerGains: state.layerGains,
            outputSelection: state.outputSelection
        )
        let scheduler = MetronomeScheduler(sampleRate: configuration.sampleRate, startSampleTime: 0, state: state)

        lock.lock()
        audioEngine = engine
        self.scheduler = scheduler
        scheduledThroughSample = -1
        isRunning = true
        lock.unlock()

        scheduleAhead(from: 0)
        try engine.start()
        startPlannerThread()
    }

    public func update(state: MetronomeState) {
        lock.lock()
        let currentStartSample = scheduler?.startSampleTime ?? 0
        scheduler = MetronomeScheduler(
            sampleRate: configuration.sampleRate,
            startSampleTime: currentStartSample,
            state: state
        )
        audioEngine?.updateGains(state.layerGains)
        lock.unlock()
    }

    public func stop() {
        lock.lock()
        isRunning = false
        plannerThread?.cancel()
        plannerThread = nil
        let engine = audioEngine
        audioEngine = nil
        scheduler = nil
        scheduledThroughSample = -1
        lock.unlock()

        engine?.stop()
    }

    private func startPlannerThread() {
        let thread = Thread { [weak self] in
            guard let self else { return }
            while self.shouldContinuePlanning() {
                self.scheduleAheadFromCurrentPlaybackPosition()
                Thread.sleep(forTimeInterval: self.configuration.refillIntervalSeconds)
            }
        }
        thread.name = "r-metronome-lookahead"

        lock.lock()
        plannerThread = thread
        lock.unlock()

        thread.start()
    }

    private func shouldContinuePlanning() -> Bool {
        lock.lock()
        let result = isRunning && !(plannerThread?.isCancelled ?? false)
        lock.unlock()
        return result
    }

    private func scheduleAheadFromCurrentPlaybackPosition() {
        lock.lock()
        let currentSample = audioEngine?.currentSampleTime()
        let fallbackSample = max(0, scheduledThroughSample)
        lock.unlock()

        scheduleAhead(from: currentSample ?? fallbackSample)
    }

    private func scheduleAhead(from currentSample: Int64) {
        let lookaheadSamples = Int64((configuration.lookaheadSeconds * configuration.sampleRate).rounded(.up))

        lock.lock()
        guard isRunning, let scheduler, let engine = audioEngine else {
            lock.unlock()
            return
        }

        let lowerBound = max(0, scheduledThroughSample + 1)
        let upperBound = max(lowerBound, currentSample + lookaheadSamples)
        guard upperBound > scheduledThroughSample else {
            lock.unlock()
            return
        }

        scheduledThroughSample = upperBound
        lock.unlock()

        let events = scheduler.events(from: lowerBound, through: upperBound)
        engine.schedule(events)
    }
}
