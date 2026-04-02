import SwiftUI

/// Draws bezier curve connections between bubbles on the debug canvas.
public struct ConnectionLinesView: View {
    let connections: [BubbleConnection]
    let bubbles: [DebugBubble]

    public init(connections: [BubbleConnection], bubbles: [DebugBubble]) {
        self.connections = connections
        self.bubbles = bubbles
    }

    public var body: some View {
        Canvas { context, _ in
            for connection in connections {
                guard let fromBubble = bubbles.first(where: { $0.id == connection.fromBubbleID }),
                      let toBubble = bubbles.first(where: { $0.id == connection.toBubbleID })
                else { continue }

                let fromPoint = CGPoint(
                    x: fromBubble.position.x + BubbleLayoutEngine.bubbleWidth,
                    y: fromBubble.position.y + 20
                )
                let toPoint = CGPoint(
                    x: toBubble.position.x,
                    y: toBubble.position.y + 20
                )

                var path = Path()
                path.move(to: fromPoint)

                // Bezier curve with horizontal control points
                let controlOffset = abs(toPoint.x - fromPoint.x) * 0.4
                path.addCurve(
                    to: toPoint,
                    control1: CGPoint(x: fromPoint.x + controlOffset, y: fromPoint.y),
                    control2: CGPoint(x: toPoint.x - controlOffset, y: toPoint.y)
                )

                let isActive = fromBubble.isActive || toBubble.isActive
                context.stroke(
                    path,
                    with: .color(isActive ? .accentColor.opacity(0.6) : .gray.opacity(0.3)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )

                // Arrowhead at the end
                drawArrowhead(context: context, at: toPoint, from: fromPoint, active: isActive)
            }
        }
    }

    private func drawArrowhead(
        context: GraphicsContext,
        at point: CGPoint,
        from: CGPoint,
        active: Bool
    ) {
        let angle = atan2(point.y - from.y, point.x - from.x)
        let arrowLength: CGFloat = 10
        let arrowAngle: CGFloat = .pi / 6

        var path = Path()
        path.move(to: point)
        path.addLine(to: CGPoint(
            x: point.x - arrowLength * cos(angle - arrowAngle),
            y: point.y - arrowLength * sin(angle - arrowAngle)
        ))
        path.move(to: point)
        path.addLine(to: CGPoint(
            x: point.x - arrowLength * cos(angle + arrowAngle),
            y: point.y - arrowLength * sin(angle + arrowAngle)
        ))

        context.stroke(
            path,
            with: .color(active ? .accentColor.opacity(0.6) : .gray.opacity(0.3)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
    }
}
