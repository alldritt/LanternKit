import SwiftUI
import LanternVM

/// A single entry in the unified console stream.
///
public enum ConsoleEntry: Identifiable {
    case output(id: UUID = UUID(), text: String)
    case repl(id: UUID = UUID(), expression: String, result: String, isError: Bool)

    public var id: UUID {
        switch self {
        case .output(let id, _): id
        case .repl(let id, _, _, _): id
        }
    }
}

/// Unified console that displays both program output and REPL interactions
/// in a single scrollable stream.
///
/// REPL input is available when paused or stopped. Expressions are evaluated
/// against the selected stack frame + globals.
///
public struct UnifiedConsoleView: View {
    let entries: [ConsoleEntry]
    let canEvaluate: Bool
    let onEvaluate: (String) -> Result<Value, InterpreterError>
    let onClear: () -> Void

    @State private var input: String = ""

    public init(entries: [ConsoleEntry],
                canEvaluate: Bool,
                onEvaluate: @escaping (String) -> Result<Value, InterpreterError>,
                onClear: @escaping () -> Void)
    {
        self.entries = entries
        self.canEvaluate = canEvaluate
        self.onEvaluate = onEvaluate
        self.onClear = onClear
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Scrollable entry stream
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(entries) { entry in
                            entryView(entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("consoleBottom")
                }
                .onChange(of: entries.count) {
                    withAnimation {
                        proxy.scrollTo("consoleBottom", anchor: .bottom)
                    }
                }
            }
            .background(.black.opacity(0.85))

            // REPL input bar
            if canEvaluate {
                Divider()
                HStack(spacing: 4) {
                    Text("⟫")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.blue)
                    TextField("Evaluate expression…", text: $input)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.plain)
                        .onSubmit(evaluateInput)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.bar)
            }
        }
    }

    // MARK: - Entry Rendering

    @ViewBuilder
    private func entryView(_ entry: ConsoleEntry) -> some View {
        switch entry {
        case .output(_, let text):
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.green)

        case .repl(_, let expression, let result, let isError):
            VStack(alignment: .leading, spacing: 1) {
                Text("⟫ \(expression)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.blue)
                Text("  \(result)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isError ? .red : .green)
            }
        }
    }

    // MARK: - REPL Evaluation

    private func evaluateInput() {
        let expr = input.trimmingCharacters(in: .whitespaces)
        guard !expr.isEmpty else { return }
        _ = onEvaluate(expr)
        input = ""
    }
}
