import SwiftUI
import LanternVM
import LanternDebugger

/// Observable wrapper over `DebuggerInterface` for SwiftUI.
///
/// Implements `DebuggerDelegate` to receive VM-thread callbacks and
/// publishes state on `@MainActor` for UI consumption. Uses the
/// debugger's own breakpoint management — no separate store.
@Observable
@MainActor
public final class DebugSession {

    // MARK: - Published State

    public private(set) var isPaused = false
    public private(set) var pausedLocation: SourceLocation?
    public private(set) var pauseReason: PauseReason?
    public private(set) var callStack: [FrameInfo] = []
    public private(set) var currentLocals: [VariableInfo] = []
    public private(set) var currentCaptures: [VariableInfo] = []
    public private(set) var events: [DebugEvent] = []
    public var selectedFrame: Int = 0

    /// The canvas model for Code Bubbles visualization.
    public let canvasModel = CanvasModel()

    /// All breakpoints managed by the debugger.
    public var breakpoints: [Breakpoint] {
        debugger.breakpoints
    }

    // MARK: - Private

    private let debugger: DebuggerInterface
    private let delegateAdapter: DebugDelegateAdapter

    // MARK: - Init

    public init(debugger: DebuggerInterface) {
        self.debugger = debugger
        self.delegateAdapter = DebugDelegateAdapter()
        self.delegateAdapter.session = self
        debugger.delegate = delegateAdapter
    }

    // MARK: - Execution Control

    public func resume() { debugger.run() }
    public func pause() { debugger.pause() }
    public func stepOver() { debugger.stepOver() }
    public func stepInto() { debugger.stepInto() }
    public func stepOut() { debugger.stepOut() }

    // MARK: - Breakpoints

    @discardableResult
    public func toggleBreakpoint(file: String, line: Int) -> Breakpoint? {
        if let existing = debugger.breakpoints.first(where: {
            if case .line(let f, let l) = $0.kind { return f == file && l == line }
            return false
        }) {
            debugger.removeBreakpoint(existing.id)
            return nil
        } else {
            return debugger.addBreakpoint(file: file, line: line, condition: nil)
        }
    }

    @discardableResult
    public func addBreakpoint(file: String, line: Int, condition: String? = nil) -> Breakpoint {
        debugger.addBreakpoint(file: file, line: line, condition: condition)
    }

    public func removeBreakpoint(_ id: UUID) {
        debugger.removeBreakpoint(id)
    }

    public var isBreakOnExceptions: Bool {
        get { debugger.isBreakOnExceptions }
        set { debugger.isBreakOnExceptions = newValue }
    }

    // MARK: - Inspection

    /// Evaluate an expression in the context of the selected frame.
    public func evaluate(expression: String) -> Result<Value, InterpreterError> {
        debugger.evaluate(expression: expression, inFrame: selectedFrame)
    }

    /// Update inspection state for the selected frame.
    public func selectFrame(_ index: Int) {
        selectedFrame = index
        refreshLocals()
    }

    // MARK: - Internal

    fileprivate func handlePause(at location: SourceLocation, reason: PauseReason) {
        isPaused = true
        pausedLocation = location
        pauseReason = reason
        callStack = debugger.callStack()
        selectedFrame = 0
        refreshLocals()
        updateCanvas()
    }

    fileprivate func handleResume() {
        isPaused = false
        pausedLocation = nil
        pauseReason = nil
        canvasModel.dimAll()
    }

    fileprivate func handleError(_ error: InterpreterError) {
        isPaused = false
    }

    fileprivate func handleEvent(_ event: DebugEvent) {
        events.append(event)
    }

    private func updateCanvas() {
        canvasModel.update(from: callStack) { [debugger] frameIndex in
            debugger.locals(frameIndex: frameIndex)
        }
    }

    private func refreshLocals() {
        guard isPaused else {
            currentLocals = []
            currentCaptures = []
            return
        }
        currentLocals = debugger.locals(frameIndex: selectedFrame)
        currentCaptures = debugger.captures(frameIndex: selectedFrame)
    }
}

// MARK: - Delegate Adapter

/// Bridges DebuggerDelegate (called on VM thread) to DebugSession (@MainActor).
///
/// We use a separate class because DebuggerDelegate requires AnyObject conformance
/// and the delegate is called on the VM thread, not MainActor.
private final class DebugDelegateAdapter: DebuggerDelegate, @unchecked Sendable {
    weak var session: DebugSession?

    func debuggerDidPause(at location: SourceLocation, reason: PauseReason) {
        let session = session
        Task { @MainActor in
            session?.handlePause(at: location, reason: reason)
        }
    }

    func debuggerDidResume() {
        let session = session
        Task { @MainActor in
            session?.handleResume()
        }
    }

    func debuggerDidEncounterError(_ error: InterpreterError) {
        let session = session
        Task { @MainActor in
            session?.handleError(error)
        }
    }

    func debuggerDidLogEvent(_ event: DebugEvent) {
        let session = session
        Task { @MainActor in
            session?.handleEvent(event)
        }
    }
}
