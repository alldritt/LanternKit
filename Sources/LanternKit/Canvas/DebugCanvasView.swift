import SwiftUI

/// Pannable, zoomable 2D canvas displaying debug bubbles.
///
/// Each call frame appears as a bubble with source context and locals.
/// Bubbles are connected by bezier curves showing the call path.
/// Supports pinch-to-zoom, drag-to-pan, and long-press-then-drag
/// for bubble repositioning.
public struct DebugCanvasView: View {
    @Bindable var canvas: CanvasModel
    let onSelectBubble: (DebugBubble) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero

    public init(
        canvas: CanvasModel,
        onSelectBubble: @escaping (DebugBubble) -> Void = { _ in }
    ) {
        self.canvas = canvas
        self.onSelectBubble = onSelectBubble
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background — captures pan gesture
                Color.clear
                    .contentShape(Rectangle())

                // Canvas content
                canvasContent
                    .scaleEffect(scale)
                    .offset(offset)
            }
            .gesture(panGesture)
            #if !os(macOS)
            .gesture(zoomGesture)
            #endif
            .onAppear {
                // Center the canvas if there are bubbles
                if !canvas.bubbles.isEmpty {
                    centerCanvas(in: geometry.size)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                zoomControls
                    .padding()
            }
        }
        .background(Color(white: 0.12))
        .clipped()
    }

    // MARK: - Canvas Content

    private var canvasContent: some View {
        ZStack(alignment: .topLeading) {
            // Connection lines (behind bubbles)
            ConnectionLinesView(
                connections: canvas.connections,
                bubbles: canvas.bubbles
            )

            // Bubbles
            ForEach(canvas.bubbles) { bubble in
                BubbleView(
                    bubble: bubble,
                    isSelected: canvas.selectedBubbleID == bubble.id,
                    onSelect: {
                        canvas.selectedBubbleID = bubble.id
                        onSelectBubble(bubble)
                    }
                )
                .position(x: bubble.position.x + BubbleLayoutEngine.bubbleWidth / 2,
                          y: bubble.position.y + 80)
                .gesture(bubbleDragGesture(for: bubble))
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    // MARK: - Canvas Size

    private var canvasSize: CGSize {
        guard !canvas.bubbles.isEmpty else {
            return CGSize(width: 1000, height: 600)
        }
        let maxX = canvas.bubbles.map { $0.position.x + BubbleLayoutEngine.bubbleWidth }.max() ?? 800
        let maxY = canvas.bubbles.map { $0.position.y + 200 }.max() ?? 400
        return CGSize(width: maxX + 100, height: maxY + 100)
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: dragStart.width + value.translation.width,
                    height: dragStart.height + value.translation.height
                )
            }
            .onEnded { _ in
                dragStart = offset
            }
    }

    #if !os(macOS)
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = max(0.25, min(3.0, value.magnification))
            }
    }
    #endif

    private func bubbleDragGesture(for bubble: DebugBubble) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let newPosition = CGPoint(
                    x: bubble.position.x + value.translation.width / scale,
                    y: bubble.position.y + value.translation.height / scale
                )
                canvas.moveButton(id: bubble.id, to: newPosition)
            }
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        VStack(spacing: 4) {
            Button {
                withAnimation { scale = min(3.0, scale * 1.25) }
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }

            Text("\(Int(scale * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                withAnimation { scale = max(0.25, scale / 1.25) }
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }

            Button {
                withAnimation { scale = 1.0; offset = .zero; dragStart = .zero }
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
        }
        .buttonStyle(.bordered)
        .font(.caption)
    }

    // MARK: - Helpers

    private func centerCanvas(in viewSize: CGSize) {
        guard let firstBubble = canvas.bubbles.first else { return }
        offset = CGSize(
            width: viewSize.width / 2 - firstBubble.position.x - BubbleLayoutEngine.bubbleWidth / 2,
            height: viewSize.height / 2 - firstBubble.position.y - 80
        )
        dragStart = offset
    }
}
