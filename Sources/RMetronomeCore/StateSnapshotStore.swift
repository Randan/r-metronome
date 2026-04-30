import Foundation

public final class StateSnapshotStore: @unchecked Sendable {
    private let lock = NSLock()
    private var currentSnapshot: MetronomeState
    private var pendingSnapshot: MetronomeState?

    public init(initialState: MetronomeState) {
        self.currentSnapshot = initialState
    }

    public func enqueue(_ state: MetronomeState) {
        lock.lock()
        pendingSnapshot = state
        lock.unlock()
    }

    public func current() -> MetronomeState {
        lock.lock()
        let snapshot = currentSnapshot
        lock.unlock()
        return snapshot
    }

    public func commitPendingAtMeasureBoundary() -> MetronomeState {
        lock.lock()
        if let pendingSnapshot {
            currentSnapshot = pendingSnapshot
            self.pendingSnapshot = nil
        }
        let snapshot = currentSnapshot
        lock.unlock()
        return snapshot
    }
}
