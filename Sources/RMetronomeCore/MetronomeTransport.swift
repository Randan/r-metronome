import Foundation

public final class MetronomeTransport: @unchecked Sendable {
    public struct Configuration: Equatable, Sendable {
        public var sampleRate: Double
        public var lookaheadSeconds: Double
        public var refillIntervalSeconds: Double
        public var updateLeadSeconds: Double

        public init(
            sampleRate: Double = 48_000,
            lookaheadSeconds: Double = 1.5,
            refillIntervalSeconds: Double = 0.25,
            updateLeadSeconds: Double = 0.05
        ) {
            precondition(sampleRate > 0, "sampleRate must be greater than zero")
            precondition(lookaheadSeconds > 0, "lookaheadSeconds must be greater than zero")
            precondition(refillIntervalSeconds > 0, "refillIntervalSeconds must be greater than zero")
            precondition(updateLeadSeconds > 0, "updateLeadSeconds must be greater than zero")
            self.sampleRate = sampleRate
            self.lookaheadSeconds = lookaheadSeconds
            self.refillIntervalSeconds = refillIntervalSeconds
            self.updateLeadSeconds = updateLeadSeconds
        }
    }

    private let configuration: Configuration
    private let lock = NSLock()
    private var audioEngine: AudioEngineManager?
    private var scheduler: MetronomeScheduler?
    private var scheduledThroughSample: Int64 = -1
    private var isRunning = false
    private var plannerThread: Thread?
    private var plannerGeneration = 0
    private var scheduleRevision = 0

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
        scheduleRevision += 1
        isRunning = true
        lock.unlock()

        do {
            scheduleAhead(from: 0)
            try engine.start()
            startPlannerThread()
        } catch {
            stop()
            throw error
        }
    }

    public func update(state: MetronomeState) {
        let updateLeadSamples = Int64((configuration.updateLeadSeconds * configuration.sampleRate).rounded(.up))
        let lookaheadSamples = Int64((configuration.lookaheadSeconds * configuration.sampleRate).rounded(.up))

        lock.lock()
        let currentStartSample = scheduler?.startSampleTime ?? 0
        let currentSample = audioEngine?.currentSampleTime() ?? max(0, scheduledThroughSample - lookaheadSamples)
        let lowerBound = max(0, currentSample + updateLeadSamples)
        let upperBound = lowerBound + lookaheadSamples

        scheduler = MetronomeScheduler(
            sampleRate: configuration.sampleRate,
            startSampleTime: currentStartSample,
            state: state
        )
        scheduleRevision += 1
        let revision = scheduleRevision
        audioEngine?.updateGains(state.layerGains)
        let scheduler = scheduler
        let engine = audioEngine
        scheduledThroughSample = upperBound
        lock.unlock()

        let events = scheduler?.events(from: lowerBound, through: upperBound) ?? []
        guard shouldScheduleEvents(for: revision) else { return }
        engine?.reschedule(events, interruptingAt: lowerBound)
    }

    public func stop() {
        lock.lock()
        isRunning = false
        plannerThread?.cancel()
        plannerThread = nil
        plannerGeneration += 1
        scheduleRevision += 1
        let engine = audioEngine
        audioEngine = nil
        scheduler = nil
        scheduledThroughSample = -1
        lock.unlock()

        engine?.stop()
    }

    private func startPlannerThread() {
        lock.lock()
        plannerGeneration += 1
        let generation = plannerGeneration
        lock.unlock()

        let thread = Thread { [weak self] in
            guard let self else { return }
            while self.shouldContinuePlanning(generation: generation) {
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

    private func shouldContinuePlanning(generation: Int) -> Bool {
        lock.lock()
        let result = isRunning
            && plannerGeneration == generation
            && !(plannerThread?.isCancelled ?? true)
        lock.unlock()
        return result
    }

    private func shouldScheduleEvents(for revision: Int) -> Bool {
        lock.lock()
        let result = isRunning && scheduleRevision == revision && audioEngine != nil
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
        let revision = scheduleRevision

        let lowerBound = max(0, scheduledThroughSample + 1)
        let upperBound = max(lowerBound, currentSample + lookaheadSamples)
        guard upperBound > scheduledThroughSample else {
            lock.unlock()
            return
        }

        scheduledThroughSample = upperBound
        lock.unlock()

        let events = scheduler.events(from: lowerBound, through: upperBound)
        guard shouldScheduleEvents(for: revision) else { return }
        engine.schedule(events)
    }
}
