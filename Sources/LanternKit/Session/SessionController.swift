import SwiftUI
import Lantern
import LanternVM
import LanternCompiler
import LanternDebugger
import LanternSwiftUI

/// Manages the compile/run/debug lifecycle for a single Lantern document.
///
/// One `SessionController` per document. Owns the `Interpreter` and routes
/// output, diagnostics, and debug events to the UI.
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
    public private(set) var diagnostics: CompilerDiagnostics?
    public private(set) var currentProgram: CompiledProgram?
    public private(set) var lastResult: Value?

    // MARK: - Preview

    /// The live preview view, if the program defines a View type.
    public private(set) var previewView: ViewStub?

    /// The view descriptor tree from the most recent body evaluation.
    public private(set) var viewDescriptor: ViewDescriptor?

    /// Whether live reload is enabled (recompile on edit).
    public var liveReloadEnabled: Bool = true

    // MARK: - Debugging

    /// The debug session, created lazily when debugging starts.
    public private(set) var debugSession: DebugSession?

    /// Whether a debug session is active.
    public var isDebugging: Bool { debugSession != nil }

    /// The underlying interpreter. Exposed for advanced use (debugger, bridge).
    /// Not Sendable — all access must happen on MainActor or via controlled offloading.
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
    }

    // MARK: - Output Handling

    private let _outputHandler: SessionOutputHandler

    // MARK: - Run

    /// Compile and execute source code.
    public func run(source: String, fileName: String = "<input>") {
        stop()
        consoleOutput = ""
        diagnostics = nil
        lastResult = nil
        state = .compiling

        let result = interpreter.compile(source: source, fileName: fileName)

        switch result {
        case .failure(let diags):
            self.diagnostics = diags
            self.state = .error

        case .success(let program):
            self.currentProgram = program
            self.state = .running

            // Interpreter is not Sendable but we guarantee exclusive access:
            // the VM runs on the detached task and nothing else touches it until completion.
            nonisolated(unsafe) let interp = interpreter
            let outputHandler = _outputHandler

            runTask = Task {
                let execResult = await Task.detached {
                    interp.execute(program: program)
                }.value

                let buffered = outputHandler.drain()

                if !buffered.isEmpty {
                    self.consoleOutput += buffered
                }

                switch execResult {
                case .success(let value):
                    self.lastResult = value
                    self.state = .finished
                case .failure(let error):
                    self.consoleOutput += "\n\(error)\n"
                    self.state = .error
                }
            }

            startOutputPolling()
        }
    }

    /// Stop the current execution.
    public func stop() {
        runTask?.cancel()
        runTask = nil
        outputPollTask?.cancel()
        outputPollTask = nil
        recompileTask?.cancel()
        recompileTask = nil
        debugSession = nil
        if state == .running || state == .paused {
            interpreter.reset()
            state = .idle
        }
    }

    /// Clear console output.
    public func clearConsole() {
        consoleOutput = ""
    }

    // MARK: - Debug

    /// Compile and start debugging.
    public func debug(source: String, fileName: String = "<input>") {
        stop()
        consoleOutput = ""
        diagnostics = nil
        lastResult = nil
        state = .compiling

        let result = interpreter.compile(source: source, fileName: fileName)

        switch result {
        case .failure(let diags):
            self.diagnostics = diags
            self.state = .error

        case .success(let program):
            self.currentProgram = program

            // Create debug session
            let session = DebugSession(debugger: interpreter.debugger)
            self.debugSession = session

            self.state = .running

            nonisolated(unsafe) let interp = interpreter
            let outputHandler = _outputHandler

            runTask = Task {
                // Execute with debugger active — will pause at breakpoints
                let execResult = await Task.detached {
                    interp.execute(program: program)
                }.value

                let buffered = outputHandler.drain()
                if !buffered.isEmpty {
                    self.consoleOutput += buffered
                }

                switch execResult {
                case .success(let value):
                    self.lastResult = value
                    self.state = .finished
                case .failure(let error):
                    self.consoleOutput += "\n\(error)\n"
                    self.state = .error
                }

                self.debugSession = nil
            }

            startOutputPolling()
        }
    }

    /// Step over (when paused).
    public func stepOver() { debugSession?.stepOver() }

    /// Step into (when paused).
    public func stepInto() { debugSession?.stepInto() }

    /// Step out (when paused).
    public func stepOut() { debugSession?.stepOut() }

    /// Resume execution (when paused).
    public func resume() { debugSession?.resume() }

    /// Pause execution.
    public func pauseExecution() { debugSession?.pause() }

    // MARK: - Preview

    /// Compile and run with preview support.
    /// Detects View-conforming types and creates a ViewStub for live preview.
    public func runWithPreview(source: String, fileName: String = "<input>") {
        run(source: source, fileName: fileName)
        detectAndCreatePreview()
    }

    /// Schedule a debounced recompile for live reload.
    public func scheduleRecompile(source: String, fileName: String = "<input>") {
        guard liveReloadEnabled else { return }
        recompileTask?.cancel()
        recompileTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self.recompile(source: source, fileName: fileName)
        }
    }

    /// The name of the detected View type, if any.
    public private(set) var detectedViewTypeName: String?

    /// Detect View types in the current program and create a preview.
    private func detectAndCreatePreview() {
        guard let program = currentProgram else {
            previewView = nil
            viewDescriptor = nil
            detectedViewTypeName = nil
            return
        }

        // Scan typeTable for types conforming to "View"
        let viewTypes = program.typeTable.filter { $0.conformances.contains("View") }

        guard let viewType = viewTypes.first else {
            previewView = nil
            viewDescriptor = nil
            detectedViewTypeName = nil
            return
        }

        detectedViewTypeName = viewType.name

        // ViewStub creation requires Interpreter.makeView(from:) which is
        // not yet implemented in Lantern (VM is private on Interpreter).
        // When that API is added, this becomes:
        //   let instance = interpreter.createInstance(typeName: viewType.name)
        //   previewView = interpreter.makeView(from: instance)
        //   viewDescriptor = interpreter.currentViewDescriptor
        previewView = nil
        viewDescriptor = nil
    }

    /// Recompile for live reload, preserving preview state when possible.
    private func recompile(source: String, fileName: String) {
        let result = interpreter.compile(source: source, fileName: fileName)

        switch result {
        case .failure(let diags):
            // Show errors but keep last good preview (dimmed via UI)
            self.diagnostics = diags

        case .success(let program):
            self.diagnostics = nil
            self.currentProgram = program
            detectAndCreatePreview()
        }
    }

    // MARK: - Output Polling

    private var outputPollTask: Task<Void, Never>?

    private func startOutputPolling() {
        outputPollTask?.cancel()
        let outputHandler = _outputHandler
        outputPollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                let text = outputHandler.drain()
                if !text.isEmpty {
                    self.consoleOutput += text
                }
            }
        }
    }
}

// MARK: - Thread-Safe Output Handler

/// Collects output on the VM thread and buffers it for main-thread consumption.
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

    /// Drain and return all buffered output. Thread-safe.
    func drain() -> String {
        lock.lock()
        let text = buffer
        buffer = ""
        lock.unlock()
        return text
    }
}
