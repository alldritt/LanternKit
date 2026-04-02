import SwiftUI
import LanternVM
import LanternDebugger

/// Individual debug bubble displaying a call frame.
///
/// Shows function name header, source text with highlighted current line,
/// and a collapsible locals inspector.
public struct BubbleView: View {
    let bubble: DebugBubble
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isLocalsExpanded = true

    public init(
        bubble: DebugBubble,
        isSelected: Bool = false,
        onSelect: @escaping () -> Void = {}
    ) {
        self.bubble = bubble
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !bubble.sourceText.isEmpty {
                Divider()
                sourceFragment
            }
            if isLocalsExpanded && !bubble.locals.isEmpty {
                Divider()
                localsInspector
            }
        }
        .frame(width: BubbleLayoutEngine.bubbleWidth)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.15), radius: bubble.isActive ? 4 : 1)
        .opacity(bubble.isActive ? 1.0 : 0.5)
        .onTapGesture(perform: onSelect)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(bubble.functionName)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
                .lineLimit(1)
            Spacer()
            if let loc = bubble.sourceLocation {
                Text("L\(loc.line)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !bubble.locals.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isLocalsExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isLocalsExpanded
                          ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(bubble.isActive ? Color.accentColor.opacity(0.1) : .clear)
    }

    // MARK: - Source Fragment

    private var sourceFragment: some View {
        Text(bubble.sourceText)
            .font(.system(.caption, design: .monospaced))
            .lineLimit(8)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Locals Inspector

    private var localsInspector: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(bubble.locals, id: \.name) { local in
                HStack(spacing: 4) {
                    Text(local.name)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("=")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(local.value.debugSummary)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
        .padding(8)
    }
}
