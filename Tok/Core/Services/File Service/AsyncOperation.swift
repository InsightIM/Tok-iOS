import Foundation

/// An abstract class that makes building simple asynchronous operations easy.
/// Subclasses must override `main()` to perform any work and call `finish()`
/// when they are done. All `NSOperation` work will be handled automatically.
///
/// Source/Inspiration: https://stackoverflow.com/a/48104095/116862 and https://gist.github.com/calebd/93fa347397cec5f88233
open class AsyncOperation: Operation {
    public init(name: String? = nil) {
        super.init()
        self.name = name
    }

    /// Serial queue for making state changes atomic under the constraint
    /// of having to send KVO willChange/didChange notifications.
    private let stateChangeQueue = DispatchQueue(label: "com.olebegemann.AsyncOperation.stateChange")

    /// Private backing store for `state`
    private var _state: Atomic<State> = Atomic(.ready)

    /// The state of the operation
    private var state: State {
        get {
            return _state.value
        }
        set {
            // A state mutation should be a single atomic transaction. We can't simply perform
            // everything on the isolation queue for `_state` because the KVO willChange/didChange
            // notifications have to be sent from outside the isolation queue. Otherwise we would
            // deadlock because KVO observers will in turn try to read `state` (by calling
            // `isReady`, `isExecuting`, `isFinished`. Use a second queue to wrap the entire
            // transaction.
            stateChangeQueue.sync {
                // Retrieve the existing value first. Necessary for sending fine-grained KVO
                // willChange/didChange notifications only for the key paths that actually change.
                let oldValue = _state.value
                guard newValue != oldValue else {
                    return
                }
                willChangeValue(forKey: oldValue.objcKeyPath)
                willChangeValue(forKey: newValue.objcKeyPath)
                _state.mutate {
                    $0 = newValue
                }
                didChangeValue(forKey: oldValue.objcKeyPath)
                didChangeValue(forKey: newValue.objcKeyPath)
            }
        }
    }

    /// Mirror of the possible states an (NS)Operation can be in
    private enum State: Int, CustomStringConvertible {
        case ready
        case executing
        case finished

        /// The `#keyPath` for the `Operation` property that's associated with this value.
        var objcKeyPath: String {
            switch self {
            case .ready: return #keyPath(isReady)
            case .executing: return #keyPath(isExecuting)
            case .finished: return #keyPath(isFinished)
            }
        }

        var description: String {
            switch self {
            case .ready: return "ready"
            case .executing: return "executing"
            case .finished: return "finished"
            }
        }
    }

    public final override var isAsynchronous: Bool { return true }

    open override var isReady: Bool {
        return state == .ready && super.isReady
    }

    public final override var isExecuting: Bool {
        return state == .executing
    }

    public final override var isFinished: Bool {
        return state == .finished
    }

    // MARK: - Foundation.Operation
    public final override func start() {
        guard !isCancelled else {
            finish()
            return
        }
        state = .executing
        main()
    }

    // MARK: - Public

    /// Subclasses must implement this to perform their work and they must not call `super`.
    /// The default implementation of this function traps.
    open override func main() {
        preconditionFailure("Subclasses must implement `main`.")
    }

    /// Call this function to finish an operation that is currently executing.
    /// State can also be "ready" here if the operation was cancelled before it started.
    public final func finish() {
        if isExecuting || isReady {
            state = .finished
        }
    }

    open override var description: String {
        return debugDescription
    }

    open override var debugDescription: String {
        return "\(type(of: self)) — \(name ?? "nil") – \(isCancelled ? "cancelled" : String(describing: state))"
    }
}
