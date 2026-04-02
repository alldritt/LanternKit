import SwiftUI
import LanternVM
import LanternDebugger

/// A single debug bubble representing a call frame on the canvas.
public struct DebugBubble: Identifiable {
    public let id: UUID
    public let frameIndex: Int
    public let functionName: String
    public let sourceLocation: SourceLocation?
    public let sourceText: String
    public let currentLine: Int?
    public let locals: [VariableInfo]
    public var position: CGPoint
    public var isActive: Bool
    public var hasManualPosition: Bool

    public init(
        frameIndex: Int,
        functionName: String,
        sourceLocation: SourceLocation?,
        sourceText: String = "",
        currentLine: Int? = nil,
        locals: [VariableInfo] = [],
        position: CGPoint = .zero,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.frameIndex = frameIndex
        self.functionName = functionName
        self.sourceLocation = sourceLocation
        self.sourceText = sourceText
        self.currentLine = currentLine
        self.locals = locals
        self.position = position
        self.isActive = isActive
        self.hasManualPosition = false
    }
}

/// A connection between two bubbles representing a call relationship.
public struct BubbleConnection: Identifiable {
    public let id: UUID
    public let fromBubbleID: UUID
    public let toBubbleID: UUID

    public init(from: UUID, to: UUID) {
        self.id = UUID()
        self.fromBubbleID = from
        self.toBubbleID = to
    }
}

/// The complete state of the debug canvas.
@Observable
@MainActor
public final class CanvasModel {
    public private(set) var bubbles: [DebugBubble] = []
    public private(set) var connections: [BubbleConnection] = []
    public var selectedBubbleID: UUID?

    public init() {}

    /// Rebuild bubbles from a call stack snapshot.
    public func update(from callStack: [FrameInfo], locals: (Int) -> [VariableInfo]) {
        let layout = BubbleLayoutEngine()
        var newBubbles = layout.layout(callStack: callStack, locals: locals)
        let newConnections = layout.connections(from: newBubbles)

        // Preserve manual positions for existing bubbles
        for i in newBubbles.indices {
            if let existing = bubbles.first(where: {
                $0.frameIndex == newBubbles[i].frameIndex
                && $0.functionName == newBubbles[i].functionName
                && $0.hasManualPosition
            }) {
                newBubbles[i].position = existing.position
                newBubbles[i].hasManualPosition = true
            }
        }

        bubbles = newBubbles
        connections = newConnections
    }

    /// Update a bubble's position after a drag.
    public func moveButton(id: UUID, to position: CGPoint) {
        guard let index = bubbles.firstIndex(where: { $0.id == id }) else { return }
        bubbles[index].position = position
        bubbles[index].hasManualPosition = true
    }

    /// Dim all bubbles (running state).
    public func dimAll() {
        for i in bubbles.indices {
            bubbles[i].isActive = false
        }
    }

    /// Clear all bubbles.
    public func clear() {
        bubbles = []
        connections = []
        selectedBubbleID = nil
    }
}
