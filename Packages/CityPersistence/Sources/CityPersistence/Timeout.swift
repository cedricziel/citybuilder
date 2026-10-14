import Foundation
import Synchronization

/// Runs `operation`, giving up with `SyncError.offline` after `timeout`,
/// or with `CancellationError` when the caller is cancelled. Either way
/// the operation is cancelled; one that ignores cancellation is left to
/// finish on its own.
func withTimeout<T: Sendable>(
    _ timeout: Duration,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let call = TimedCall<T>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            call.begin(continuation)
            call.track(Task {
                do {
                    try await call.finish(.success(operation()))
                } catch {
                    call.finish(.failure(error))
                }
            })
            call.track(Task {
                try? await Task.sleep(for: timeout)
                call.finish(.failure(SyncError.offline))
            })
        }
    } onCancel: {
        call.finish(.failure(CancellationError()))
    }
}

/// One timed call: the first result wins, resumes the caller and cancels
/// the call's tasks.
private final class TimedCall<T: Sendable>: Sendable {
    private struct State {
        var continuation: CheckedContinuation<T, Error>?
        var result: Result<T, Error>?
        var tasks: [Task<Void, Never>] = []
    }

    private let state = Mutex(State())

    /// Resumes at once if the call already finished (cancelled early).
    func begin(_ continuation: CheckedContinuation<T, Error>) {
        let finished = state.withLock { state -> Result<T, Error>? in
            if state.result == nil { state.continuation = continuation }
            return state.result
        }
        if let finished { continuation.resume(with: finished) }
    }

    func track(_ task: Task<Void, Never>) {
        let finished = state.withLock { state -> Bool in
            if state.result == nil { state.tasks.append(task) }
            return state.result != nil
        }
        if finished { task.cancel() }
    }

    func finish(_ result: Result<T, Error>) {
        let (continuation, tasks) = state.withLock { state -> (CheckedContinuation<T, Error>?, [Task<Void, Never>]) in
            guard state.result == nil else { return (nil, []) }
            state.result = result
            defer {
                state.continuation = nil
                state.tasks = []
            }
            return (state.continuation, state.tasks)
        }
        tasks.forEach { $0.cancel() }
        continuation?.resume(with: result)
    }
}
