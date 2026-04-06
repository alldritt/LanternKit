import SwiftUI
import Lantern
import LanternVM
import LanternCompiler
import LanternDebugger
import LanternSwiftUI

/// Manages the compile/run/debug lifecycle for a single Lantern document.
///
/// One `SessionController` per document. The debugger is always active —
/// breakpoints work in every run, and stepping is always available.
///
/// **Preview model:** The preview panel displays whatever value the script
/// produces as its result. If the result is a SwiftUI view (ViewBox), it's
/// rendered live. If it's a scalar value, it's displayed as formatted text.
/// This means the script controls what gets previewed:
///
///     Text("Hello!")              // previews a Text view
///     struct MyView: View { ... }
///     MyView()                    // previews MyView
///     fibonacci(10)               // previews "55"
///
@Observable
@MainActor
public final class SessionController {

    // MARK: - State

    public enum State: Equatable {
        case idle
        case compiling
        case running
        case paused
        case finished
        case error
    }

    public private(set) var state: State = .idle
    public private(set) var consoleOutput: String = ""
    public private(set) var consoleEntries: [ConsoleEntry] = []
    public private(set) var diagnostics: CompilerDiagnostics?
    public private(set) var currentProgram: CompiledProgram?

    /// The result of the last execution.
    public private(set) var lastResult: Value?

    /// The value to display in the preview panel.
    /// When paused: the result of the last executed statement.
    /// When finished: the script's final result.
    /// Otherwise: nil.
    public var previewValue: Value? {
        let raw: Value?
        switch state {
        case .paused:
            raw = debugSession.lastStatementResult
        case .finished:
            raw = lastResult
        default:
            raw = lastResult // Keep showing last result while idle
        }
        // Wrap View-conforming instances in ViewBox for live preview
        guard let raw else { return nil }
        return interpreter.wrapViewInstanceIfNeeded(raw)
    }

    public var liveReloadEnabled: Bool = true

    // MARK: - Debugging

    /// The debug session. Always available — debugging is always on.
    public let debugSession: DebugSession

    /// The underlying interpreter.
    public let interpreter: Interpreter

    private var runTask: Task<Void, Never>?
    private var recompileTask: Task<Void, Never>?

    // MARK: - Init

    public init() {
        let interp = Interpreter()
        let handler = SessionOutputHandler()
        interp.outputHandler = handler
        self.interpreter = interp
        self._outputHandler = handler

        let builtinNames = Set(interp.debugger.globals().map(\.name))

        self.debugSession = DebugSession(debugger: interp.debugger, builtinGlobalNames: builtinNames)
        self.debugSession.onPause = { [weak self] in self?.state = .paused }
        self.debugSession.onResume = { [weak self] in
            guard let self, self.state == .paused else { return }
            self.state = .running
        }
    }

    // MARK: - Output Handling

    private let _outputHandler: SessionOutputHandler

    // MARK: - Execution

    /// Compile and run to completion. Breakpoints are honoured.
    public func run(source: String, fileName: String = "<input>") {
        prepareForRun()
        guard let program = compile(source: source, fileName: fileName) else { return }
        state = .running
        execute(program: program)
    }

    /// Step over one statement. From idle: compile and pause at first statement.
    public func stepOver(source: String, fileName: String = "<input>") {
        if state == .paused {
            debugSession.stepOver()
            return
        }
        prepareForRun()
        guard let program = compile(source: source, fileName: fileName) else { return }
        state = .running
        executePaused(program: program)
    }

    /// Step into. From idle: compile and pause at first statement.
    public func stepInto(source: String, fileName: String = "<input>") {
        if state == .paused {
            debugSession.stepInto()
            return
        }
        prepareForRun()
        guard let program = compile(source: source, fileName: fileName) else { return }
        state = .running
        executePaused(program: program)
    }

    /// Step out of current function.
    public func stepOut() {
        guard state == .paused else { return }
        debugSession.stepOut()
    }

    /// Resume execution when paused.
    public func resume() {
        guard state == .paused else { return }
        debugSession.resume()
    }

    /// Pause execution.
    public func pauseExecution() {
        guard state == .running else { return }
        debugSession.pause()
    }

    /// Stop execution and reset to idle.
    public func stop() {
        runTask?.cancel()
        runTask = nil
        outputPollTask?.cancel()
        outputPollTask = nil
        recompileTask?.cancel()
        recompileTask = nil
        if state == .running || state == .paused {
            interpreter.reset()
        }
        state = .idle
    }

    /// Clear console output.
    public func clearConsole() {
        consoleOutput = ""
        consoleEntries = []
    }

    /// Evaluate a REPL expression and append the result to the console stream.
    public func evaluateREPL(expression: String) -> Result<Value, InterpreterError> {
        let result = debugSession.evaluate(expression: expression)
        switch result {
        case .success(let value):
            consoleEntries.append(.repl(expression: expression, result: value.debugSummary, isError: false))
        case .failure(let error):
            consoleEntries.append(.repl(expression: expression, result: error.message, isError: true))
        }
        return result
    }

    // MARK: - Private Execution Helpers

    private func prepareForRun() {
        stop()
        consoleOutput = ""
        consoleEntries = []
        diagnostics = nil
        lastResult = nil
        state = .compiling
    }

    @discardableResult
    private func compile(source: String, fileName: String) -> CompiledProgram? {
        let result = interpreter.compile(source: source, fileName: fileName)
        switch result {
        case .failure(let diags):
            self.diagnostics = diags
            self.state = .error
            return nil
        case .success(let program):
            self.currentProgram = program
            return program
        }
    }

    private func execute(program: CompiledProgram) {
        nonisolated(unsafe) let interp = interpreter
        let outputHandler = _outputHandler

        runTask = Task {
            let execResult = await Task.detached {
                interp.execute(program: program)
            }.value

            let buffered = outputHandler.drain()
            if !buffered.isEmpty {
                self.appendOutput(buffered)
            }

            switch execResult {
            case .success(let value):
                self.lastResult = value
                self.populateGlobalsAfterExecution()
                self.state = .finished
            case .failure(let error):
                self.appendOutput("\n\(error)\n")
                self.state = .error
            }
        }

        startOutputPolling()
    }

    private func executePaused(program: CompiledProgram) {
        nonisolated(unsafe) let interp = interpreter
        let outputHandler = _outputHandler

        runTask = Task {
            let execResult = await Task.detached {
                interp.executePaused(program: program)
            }.value

            let buffered = outputHandler.drain()
            if !buffered.isEmpty {
                self.appendOutput(buffered)
            }

            switch execResult {
            case .success(let value):
                // If paused, the delegate already set state to .paused
                if self.state != .paused {
                    self.lastResult = value
                    self.populateGlobalsAfterExecution()
                    self.state = .finished
                }
            case .failure(let error):
                self.appendOutput("\n\(error)\n")
                self.state = .error
            }
        }

        startOutputPolling()
    }

    // MARK: - Live Reload

    public func scheduleRecompile(source: String, fileName: String = "<input>") {
        guard liveReloadEnabled else { return }
        guard state == .idle || state == .finished || state == .error else { return }
        recompileTask?.cancel()
        recompileTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self.run(source: source, fileName: fileName)
        }
    }

    // MARK: - Output Polling

    private var outputPollTask: Task<Void, Never>?

    /// Populate globals on the debug session after script execution completes,
    /// so the Variables panel can display them.
    private func populateGlobalsAfterExecution() {
        let allGlobals = interpreter.debugger.globals()
        let filtered = allGlobals.filter { !debugSession.builtinGlobalNames.contains($0.name) }
        debugSession.setGlobals(filtered)
    }

    private func appendOutput(_ text: String) {
        consoleOutput += text
        // Split into lines and append as individual entries for the unified console
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        for line in lines {
            consoleEntries.append(.output(text: line))
        }
    }

    private func startOutputPolling() {
        outputPollTask?.cancel()
        let outputHandler = _outputHandler
        outputPollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                let text = outputHandler.drain()
                if !text.isEmpty {
                    self.appendOutput(text)
                }
            }
        }
    }
}

// MARK: - Thread-Safe Output Handler

final class SessionOutputHandler: OutputHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: String = ""

    func handlePrint(_ text: String) {
        lock.lock()
        buffer += text
        lock.unlock()
    }

    func handleDebugPrint(_ text: String) {
        lock.lock()
        buffer += text
        lock.unlock()
    }

    func drain() -> String {
        lock.lock()
        let text = buffer
        buffer = ""
        lock.unlock()
        return text
    }
}
