import SwiftUI
import LanternVM
import LanternDebugger

/// Displays variables with expandable compound values.
///
/// Uses `Value.debugChildren` for recursive expansion via DisclosureGroup.
/// Shows type name, mutability badge, and debug summary.
public struct VariablesPanel: View {
    let locals: [VariableInfo]
    let captures: [VariableInfo]

    public init(locals: [VariableInfo], captures: [VariableInfo] = []) {
        self.locals = locals
        self.captures = captures
    }

    public var body: some View {
        List {
            if !locals.isEmpty {
                Section("Locals") {
                    ForEach(locals, id: \.name) { variable in
                        VariableRow(variable: variable)
                    }
                }
            }
            if !captures.isEmpty {
                Section("Captures") {
                    ForEach(captures, id: \.name) { variable in
                        VariableRow(variable: variable)
                    }
                }
            }
            if locals.isEmpty && captures.isEmpty {
                ContentUnavailableView(
                    "No Variables",
                    systemImage: "xmark.circle",
                    description: Text("No variables in scope.")
                )
            }
        }
        .listStyle(.plain)
    }
}

/// A single variable row with optional expansion for compound values.
private struct VariableRow: View {
    let variable: VariableInfo

    var body: some View {
        if let children = variable.value.debugChildren, !children.isEmpty {
            DisclosureGroup {
                ForEach(children, id: \.label) { child in
                    ValueRow(label: child.label, value: child.value)
                }
            } label: {
                variableLabel
            }
        } else {
            variableLabel
        }
    }

    private var variableLabel: some View {
        HStack {
            HStack(spacing: 4) {
                Text(variable.isMutable ? "var" : "let")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(variable.isMutable ? .blue : .purple)
                Text(variable.name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
            }

            Text(variable.typeName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(variable.value.debugSummary)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.orange)
                .lineLimit(1)
        }
    }
}

/// A child value row (for expanded compound values).
private struct ValueRow: View {
    let label: String
    let value: Value

    var body: some View {
        if let children = value.debugChildren, !children.isEmpty {
            DisclosureGroup {
                ForEach(children, id: \.label) { child in
                    ValueRow(label: child.label, value: child.value)
                }
            } label: {
                rowContent
            }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .monospaced))
            Spacer()
            Text(value.debugSummary)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.orange)
                .lineLimit(1)
        }
    }
}
