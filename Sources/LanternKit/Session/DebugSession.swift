import SwiftUI
import LanternVM
import LanternDebugger

/// Observable wrapper over `DebuggerInterface` for SwiftUI.
///
/// The debugger delegate fires on the VM thread. We capture all inspection
/// data (call stack, locals) on that thread while the VM is paused, then
/// send the snapshots to @MainActor for display.
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
    public private(set) var currentGlobals: [VariableInfo] = []
    public private(set) var events: [DebugEvent] = []
    public var selectedFrame: Int = 0

    /// The canvas model for Code Bubbles visualization.
    public let canvasModel = CanvasModel()

    /// Called when the debugger pauses. Used by SessionController to update state.
    public var onPause: (() -> Void)?

    /// Called when the debugger resumes. Used by SessionController to update state.
    public var onResume: (() -> Void)?

    /// All breakpoints managed by the debugger.
    public var breakpoints: [Breakpoint] {
        debugger.breakpoints
    }

    // MARK: - Private

    // Internal access so the delegate adapter can query the debugger on the VM thread
    let debugger: DebuggerInterface
    private let delegateAdapter: DebugDelegateAdapter
    /// Names of built-in globals to exclude from variable display.
    let builtinGlobalNames: Set<String>

    // MARK: - Init

    public init(debugger: DebuggerInterface, builtinGlobalNames: Set<String> = []) {
        self.debugger = debugger
        self.builtinGlobalNames = builtinGlobalNames
        self.delegateAdapter = DebugDelegateAdapter(debugger: debugger, builtinGlobalNames: builtinGlobalNames)
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
        // Re-fetch locals for the new frame from the debugger
        // (only valid while paused — the debugger holds state)
        if isPaused {
            currentLocals = debugger.locals(frameIndex: index)
            currentCaptures = debugger.captures(frameIndex: index)
        }
    }

    // MARK: - Internal (called from delegate adapter)

    /// Called with data captured on the VM thread while paused.
    fileprivate func applyPauseSnapshot(_ snapshot: PauseSnapshot) {
        isPaused = true
        pausedLocation = snapshot.location
        pauseReason = snapshot.reason
        callStack = snapshot.callStack
        selectedFrame = 0
        currentLocals = snapshot.locals
        currentCaptures = snapshot.captures
        currentGlobals = snapshot.globals
        updateCanvas()
        onPause?()
    }

    fileprivate func handleResume() {
        isPaused = false
        pausedLocation = nil
        pauseReason = nil
        callStack = []
        currentLocals = []
        currentCaptures = []
        currentGlobals = []
        canvasModel.dimAll()
        onResume?()
    }

    fileprivate func handleError(_ error: InterpreterError) {
        isPaused = false
    }

    fileprivate func handleEvent(_ event: DebugEvent) {
        events.append(event)
    }

    private func updateCanvas() {
        // Use the already-captured call stack data, don't re-query the debugger
        var localsMap: [Int: [VariableInfo]] = [:]
        localsMap[0] = currentLocals
        canvasModel.update(from: callStack) { frameIndex in
            localsMap[frameIndex] ?? []
        }
    }
}

// MARK: - Pause Snapshot

/// All inspection data captured on the VM thread while the VM is paused.
/// This is sent to @MainActor so we don't need to query the debugger
/// from the wrong thread.
struct PauseSnapshot: Sendable {
    let location: SourceLocation
    let reason: PauseReason
    let callStack: [FrameInfo]
    let locals: [VariableInfo]
    let captures: [VariableInfo]
    let globals: [VariableInfo]
}

// MARK: - Delegate Adapter

/// Bridges DebuggerDelegate (called on VM thread) to DebugSession (@MainActor).
///
/// Captures all inspection data on the VM thread while paused, then
/// sends the snapshot to MainActor. This avoids cross-thread debugger queries.
private final class DebugDelegateAdapter: DebuggerDelegate, @unchecked Sendable {
    weak var session: DebugSession?
    let debugger: DebuggerInterface
    let builtinGlobalNames: Set<String>

    init(debugger: DebuggerInterface, builtinGlobalNames: Set<String>) {
        self.debugger = debugger
        self.builtinGlobalNames = builtinGlobalNames
    }

    func debuggerDidPause(at location: SourceLocation, reason: PauseReason) {
        // Capture everything NOW, on the VM thread, while the VM is actually paused
        let stack = debugger.callStack()
        let locals = debugger.locals(frameIndex: 0)
        let captures = debugger.captures(frameIndex: 0)
        // Filter out built-in globals (print, min, max, String, Double, etc.)
        let globals = debugger.globals().filter { !builtinGlobalNames.contains($0.name) }

        let snapshot = PauseSnapshot(
            location: location,
            reason: reason,
            callStack: stack,
            locals: locals,
            captures: captures,
            globals: globals
        )

        let session = session
        Task { @MainActor in
            session?.applyPauseSnapshot(snapshot)
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
