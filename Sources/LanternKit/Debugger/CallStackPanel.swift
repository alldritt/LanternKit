import SwiftUI
import LanternVM
import LanternDebugger

/// Displays the call stack with frame selection.
///
/// Each row shows the function name and source location.
/// Host frames (bridge calls) are styled differently.
public struct CallStackPanel: View {
    let frames: [FrameInfo]
    let selectedFrame: Int
    let onSelectFrame: (Int) -> Void

    public init(
        frames: [FrameInfo],
        selectedFrame: Int,
        onSelectFrame: @escaping (Int) -> Void
    ) {
        self.frames = frames
        self.selectedFrame = selectedFrame
        self.onSelectFrame = onSelectFrame
    }

    public var body: some View {
        List(frames, id: \.frameIndex) { frame in
            Button {
                onSelectFrame(frame.frameIndex)
            } label: {
                HStack {
                    Image(systemName: frame.isHostFrame ? "gear" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(frame.isHostFrame ? .orange : .blue)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(frame.functionName)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(frame.frameIndex == selectedFrame ? .bold : .regular)

                        if let loc = frame.sourceLocation {
                            Text("line \(loc.line)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if frame.frameIndex == selectedFrame {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }
            .buttonStyle(.plain)
            .opacity(frame.isHostFrame ? 0.6 : 1.0)
        }
        .listStyle(.plain)
    }
}
