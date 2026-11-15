import CityCore
import Foundation

/// What asked for an autosave.
public enum AutosaveTrigger: Sendable, Equatable {
    /// The app is leaving the foreground or is about to terminate. Written
    /// before returning, because the system may suspend the process.
    case leavingForeground
    case seasonChange
    case interval
}

public enum AutosaveResult: Sendable, Equatable {
    case saved(Date)
    case failed(String)
}

/// The wall clock, injectable so tests never wait. The simulation never reads it.
public protocol AutosaveClock: Sendable {
    func now() -> Date
}

public struct SystemAutosaveClock: AutosaveClock {
    public init() {}
    public func now() -> Date {
        Date()
    }
}

/// Which worlds an autosave may replace the slot with.
public enum AutosavePolicy {
    /// False for a town not yet played, a bankrupt one and a lost scenario:
    /// none of them may replace a live town in the slot.
    public static func allows(_ world: World) -> Bool {
        world.tickCount > 0 && !world.isBankrupt && !world.economy.gameOver && world.scenarioLoss == nil
    }
}

/// Autosaves one game into its slot. Takes the snapshot on the main actor,
/// then encodes and writes on a serial queue, so the game never waits for the
/// disk. Triggers that arrive while a write runs coalesce into one more write
/// with a fresh snapshot afterwards. Leaving the foreground writes before it
/// returns.
@MainActor
public final class AutosaveCoordinator {
    public static let defaultInterval: TimeInterval = 300

    public let gameID: UUID
    public private(set) var lastSavedAt: Date?

    private let store: SaveStore
    private let clock: any AutosaveClock
    private let interval: TimeInterval
    private let worldProvider: @MainActor () -> World?
    private let onResult: @MainActor (AutosaveResult) -> Void
    private let queue = DispatchQueue(label: "citybuilder.autosave", qos: .utility)

    private var lastAttempt: Date
    private var lastSavedTick: UInt64?
    private var inFlight: Task<Void, Never>?
    private var hasPending = false
    private var isStopped = false

    /// `worldProvider` returns the world as it stands now, or nil when there
    /// is nothing to save (the game ended or is not a real game).
    public init(
        store: SaveStore,
        gameID: UUID,
        clock: any AutosaveClock = SystemAutosaveClock(),
        interval: TimeInterval = AutosaveCoordinator.defaultInterval,
        worldProvider: @escaping @MainActor () -> World?,
        onResult: @escaping @MainActor (AutosaveResult) -> Void = { _ in }
    ) {
        self.store = store
        self.gameID = gameID
        self.clock = clock
        self.interval = interval
        self.worldProvider = worldProvider
        self.onResult = onResult
        lastAttempt = clock.now()
    }

    /// Called every simulation step; asks for a save once the interval has passed.
    public func playStepped() {
        guard !isStopped, clock.now().timeIntervalSince(lastAttempt) >= interval else { return }
        request(.interval)
    }

    public func request(_ trigger: AutosaveTrigger) {
        guard !isStopped else { return }
        if trigger == .leavingForeground {
            writeNow()
        } else if inFlight != nil {
            hasPending = true
        } else {
            startWrite()
        }
    }

    /// The game is over for this coordinator; later triggers do nothing.
    public func stop() {
        isStopped = true
    }

    /// Resolves once no write is running or waiting. For tests.
    public func waitUntilIdle() async {
        while let task = inFlight {
            await task.value
        }
    }

    private func snapshot() -> (world: World, date: Date)? {
        guard let world = worldProvider(), AutosavePolicy.allows(world), world.tickCount != lastSavedTick else { return nil }
        lastAttempt = clock.now()
        return (world, lastAttempt)
    }

    private func startWrite() {
        guard let (world, date) = snapshot() else { return }
        let store = store, gameID = gameID, queue = queue
        inFlight = Task { [weak self] in
            let outcome: Result<Void, Error> = await withCheckedContinuation { continuation in
                queue.async {
                    continuation.resume(returning: Result { try store.autosave(world, gameID: gameID, at: date) })
                }
            }
            self?.finish(outcome, tick: world.tickCount, date: date)
        }
    }

    private func writeNow() {
        guard let (world, date) = snapshot() else { return }
        let store = store, gameID = gameID
        let outcome = queue.sync { Result { try store.autosave(world, gameID: gameID, at: date) } }
        hasPending = false
        record(outcome, tick: world.tickCount, date: date)
    }

    private func finish(_ outcome: Result<Void, Error>, tick: UInt64, date: Date) {
        inFlight = nil
        record(outcome, tick: tick, date: date)
        if hasPending {
            hasPending = false
            startWrite()
        }
    }

    private func record(_ outcome: Result<Void, Error>, tick: UInt64, date: Date) {
        switch outcome {
        case .success:
            if lastSavedTick.map({ tick >= $0 }) ?? true {
                lastSavedTick = tick
            }
            lastSavedAt = date
            onResult(.saved(date))
        case let .failure(error):
            onResult(.failed("\(error)"))
        }
    }
}
