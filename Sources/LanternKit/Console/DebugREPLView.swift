import SwiftUI
import LanternVM

/// Expression evaluator for use when paused in the debugger.
///
/// Accepts expressions, evaluates them in the current frame context,
/// and displays results in a scrollable history.
public struct DebugREPLView: View {
    let isPaused: Bool
    let onEvaluate: (String) -> Result<Value, InterpreterError>

    @State private var input: String = ""
    @State private var history: [REPLEntry] = []

    public init(
        isPaused: Bool,
        onEvaluate: @escaping (String) -> Result<Value, InterpreterError>
    ) {
        self.isPaused = isPaused
        self.onEvaluate = onEvaluate
    }

    public var body: some View {
        VStack(spacing: 0) {
            // History
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(history) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("> \(entry.expression)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.blue)
                                Text(entry.result)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(entry.isError ? .red : .green)
                            }
                            .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: history.count) {
                    if let last = history.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input
            HStack {
                Text(">")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                TextField("Evaluate expression...", text: $input)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .disabled(!isPaused)
                    .onSubmit(evaluateInput)
            }
            .padding(8)
            .background(.bar)
        }
    }

    private func evaluateInput() {
        let expr = input.trimmingCharacters(in: .whitespaces)
        guard !expr.isEmpty else { return }

        let result = onEvaluate(expr)
        let entry: REPLEntry
        switch result {
        case .success(let value):
            entry = REPLEntry(expression: expr, result: value.debugSummary, isError: false)
        case .failure(let error):
            entry = REPLEntry(expression: expr, result: error.message, isError: true)
        }
        history.append(entry)
        input = ""
    }
}

private struct REPLEntry: Identifiable {
    let id = UUID()
    let expression: String
    let result: String
    let isError: Bool
}
