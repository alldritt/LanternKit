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

    public private(set) var previewView: ViewStub?
    public private(set) var viewDescriptor: ViewDescriptor?
    public private(set) var detectedViewTypeName: String?
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
        self.debugSession = DebugSession(debugger: interp.debugger)
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

    /// Compile and immediately pause before the first statement.
    /// Use when stepping from idle.
    public func stepOver(source: String, fileName: String = "<input>") {
        if state == .paused {
            debugSession.stepOver()
            return
        }
        prepareForRun()
        guard compile(source: source, fileName: fileName) != nil else { return }
        // The debugger will step and pause at the first statement
        debugSession.stepOver()
    }

    /// Step into from current position, or compile and step into first call.
    public func stepInto(source: String, fileName: String = "<input>") {
        if state == .paused {
            debugSession.stepInto()
            return
        }
        prepareForRun()
        guard compile(source: source, fileName: fileName) != nil else { return }
        debugSession.stepInto()
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
    }

    // MARK: - Private Execution Helpers

    private func prepareForRun() {
        stop()
        consoleOutput = ""
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
            detectAndCreatePreview()
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

    // MARK: - Preview

    public func runWithPreview(source: String, fileName: String = "<input>") {
        run(source: source, fileName: fileName)
    }

    public func scheduleRecompile(source: String, fileName: String = "<input>") {
        guard liveReloadEnabled else { return }
        recompileTask?.cancel()
        recompileTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self.recompile(source: source, fileName: fileName)
        }
    }

    private func detectAndCreatePreview() {
        guard let program = currentProgram else {
            previewView = nil
            viewDescriptor = nil
            detectedViewTypeName = nil
            return
        }

        let viewTypes = program.typeTable.filter { $0.conformances.contains("View") }
        guard let viewType = viewTypes.first else {
            previewView = nil
            viewDescriptor = nil
            detectedViewTypeName = nil
            return
        }

        detectedViewTypeName = viewType.name
        previewView = nil
        viewDescriptor = nil
    }

    private func recompile(source: String, fileName: String) {
        let result = interpreter.compile(source: source, fileName: fileName)
        switch result {
        case .failure(let diags):
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
