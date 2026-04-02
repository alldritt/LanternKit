import SwiftUI
import Lantern
import LanternVM
import LanternCompiler
import LanternDebugger

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

    /// The underlying interpreter. Exposed for advanced use (debugger, bridge).
    /// Not Sendable — all access must happen on MainActor or via controlled offloading.
    public let interpreter: Interpreter

    private var runTask: Task<Void, Never>?

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
        if state == .running || state == .paused {
            interpreter.reset()
            state = .idle
        }
    }

    /// Clear console output.
    public func clearConsole() {
        consoleOutput = ""
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
