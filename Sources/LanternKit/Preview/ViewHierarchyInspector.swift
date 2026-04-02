import SwiftUI
import LanternVM
import LanternSwiftUI

/// Tree view of the ViewDescriptor hierarchy for debugging and inspection.
///
/// Each node shows the view type, modifiers, and source location.
/// Tapping a node fires the `onSelectNode` callback with its source location.
public struct ViewHierarchyInspector: View {
    let descriptor: ViewDescriptor?
    let onSelectNode: (SourceLocation) -> Void

    public init(
        descriptor: ViewDescriptor?,
        onSelectNode: @escaping (SourceLocation) -> Void = { _ in }
    ) {
        self.descriptor = descriptor
        self.onSelectNode = onSelectNode
    }

    public var body: some View {
        Group {
            if let descriptor {
                List {
                    DescriptorNode(
                        descriptor: descriptor,
                        onSelectNode: onSelectNode
                    )
                }
                #if os(macOS)
                .listStyle(.sidebar)
                #endif
            } else {
                ContentUnavailableView(
                    "No View Hierarchy",
                    systemImage: "list.bullet.indent",
                    description: Text("Run a script with a View to inspect its hierarchy.")
                )
            }
        }
        .navigationTitle("View Hierarchy")
    }
}

/// A single node in the view descriptor tree.
private struct DescriptorNode: View {
    let descriptor: ViewDescriptor
    let onSelectNode: (SourceLocation) -> Void

    var body: some View {
        DisclosureGroup {
            // Modifiers
            ForEach(Array(descriptor.modifiers.enumerated()), id: \.offset) { _, modifier in
                HStack {
                    Image(systemName: "paintbrush")
                        .foregroundStyle(.secondary)
                    Text(".\(modifier.name)")
                        .font(.system(.caption, design: .monospaced))
                    if !modifier.arguments.isEmpty {
                        Text("(\(formatArguments(modifier.arguments)))")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 8)
            }

            // Children
            ForEach(Array(descriptor.children.enumerated()), id: \.offset) { _, child in
                DescriptorNode(
                    descriptor: child,
                    onSelectNode: onSelectNode
                )
            }
        } label: {
            Button {
                onSelectNode(descriptor.sourceLocation)
            } label: {
                HStack {
                    Image(systemName: iconForType(descriptor.typeName))
                        .foregroundStyle(.blue)
                    Text(descriptor.typeName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    Spacer()
                    Text("L\(descriptor.sourceLocation.line)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func iconForType(_ typeName: String) -> String {
        switch typeName {
        case "VStack", "HStack", "ZStack": "square.stack"
        case "Text": "textformat"
        case "Button": "button.horizontal"
        case "Image": "photo"
        case "List": "list.bullet"
        case "NavigationStack", "NavigationSplitView": "sidebar.left"
        case "ScrollView": "scroll"
        case "TextField", "TextEditor": "character.cursor.ibeam"
        case "Toggle": "switch.2"
        case "Slider": "slider.horizontal.3"
        case "Picker": "filemenu.and.selection"
        default: "square"
        }
    }

    private func formatArguments(_ args: [String: Value]) -> String {
        args.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}
