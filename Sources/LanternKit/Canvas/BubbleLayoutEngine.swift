import Foundation
import LanternVM
import LanternDebugger

/// Computes bubble positions from a call stack.
///
/// Default layout: left-to-right in call order (deepest frame rightmost).
/// Bubbles are spaced with padding for connection lines.
public struct BubbleLayoutEngine {
    public static let bubbleWidth: CGFloat = 380
    public static let bubbleSpacing: CGFloat = 60
    public static let startX: CGFloat = 40
    public static let startY: CGFloat = 40

    public init() {}

    /// Create bubbles from a call stack, positioned left-to-right.
    /// Frame 0 is the top (most recent) — placed rightmost.
    public func layout(
        callStack: [FrameInfo],
        locals: (Int) -> [VariableInfo]
    ) -> [DebugBubble] {
        // Reverse so deepest caller is leftmost, current frame is rightmost
        let reversed = callStack.reversed()
        var bubbles: [DebugBubble] = []

        for (layoutIndex, frame) in reversed.enumerated() {
            let x = Self.startX + CGFloat(layoutIndex) * (Self.bubbleWidth + Self.bubbleSpacing)

            var bubble = DebugBubble(
                frameIndex: frame.frameIndex,
                functionName: frame.functionName,
                sourceLocation: frame.sourceLocation,
                currentLine: frame.sourceLocation.map { Int($0.line) },
                locals: locals(frame.frameIndex),
                position: CGPoint(x: x, y: Self.startY),
                isActive: frame.frameIndex == 0
            )

            // Format arguments as source text snippet
            if !frame.arguments.isEmpty {
                let args = frame.arguments.map { arg in
                    let label = arg.label.map { "\($0): " } ?? ""
                    return "\(label)\(arg.value.debugSummary)"
                }.joined(separator: ", ")
                bubble = DebugBubble(
                    frameIndex: bubble.frameIndex,
                    functionName: bubble.functionName,
                    sourceLocation: bubble.sourceLocation,
                    sourceText: "\(frame.functionName)(\(args))",
                    currentLine: bubble.currentLine,
                    locals: bubble.locals,
                    position: bubble.position,
                    isActive: bubble.isActive
                )
            }

            bubbles.append(bubble)
        }

        return bubbles
    }

    /// Create connections between adjacent bubbles (caller → callee).
    public func connections(from bubbles: [DebugBubble]) -> [BubbleConnection] {
        guard bubbles.count > 1 else { return [] }
        var connections: [BubbleConnection] = []
        for i in 0..<(bubbles.count - 1) {
            connections.append(BubbleConnection(from: bubbles[i].id, to: bubbles[i + 1].id))
        }
        return connections
    }
}
