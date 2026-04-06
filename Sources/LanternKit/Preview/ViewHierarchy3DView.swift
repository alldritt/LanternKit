import SwiftUI
import LanternVM
import LanternSwiftUI

/// 3D exploded view of the view hierarchy, modeled after Xcode's View Hierarchy debugger.
///
/// Shows each view as a layer in a perspective projection. A slider controls the
/// spacing between layers. Clicking a layer selects it and highlights it.
///
public struct ViewHierarchy3DView: View {
    let descriptor: ViewDescriptor?
    let onSelectNode: (SourceLocation) -> Void

    @State private var layerSpacing: CGFloat = 40
    @State private var rotation: CGFloat = 30       // degrees of Y rotation
    @State private var selectedLocation: SourceLocation?

    public init(descriptor: ViewDescriptor?,
                onSelectNode: @escaping (SourceLocation) -> Void = { _ in })
    {
        self.descriptor = descriptor
        self.onSelectNode = onSelectNode
    }

    public var body: some View {
        if let descriptor {
            VStack(spacing: 0) {
                // 3D exploded canvas
                GeometryReader { geo in
                    let layers = descriptor.flattened()
                    let centerX = geo.size.width / 2
                    let centerY = geo.size.height / 2

                    ZStack {
                        ForEach(Array(layers.enumerated()), id: \.offset) { index, node in
                            let zOffset = CGFloat(index) * layerSpacing
                            let isSelected = node.sourceLocation == selectedLocation

                            layerView(node: node, isSelected: isSelected)
                                .frame(width: layerWidth(for: node, in: geo.size),
                                       height: layerHeight(for: node, in: geo.size))
                                .offset(y: -zOffset * 0.3)  // vertical stacking
                                .rotation3DEffect(
                                    .degrees(rotation),
                                    axis: (x: 0.15, y: 1, z: 0),
                                    perspective: 0.5
                                )
                                .offset(x: zOffset * 0.15)   // lateral perspective shift
                                .onTapGesture {
                                    selectedLocation = node.sourceLocation
                                    onSelectNode(node.sourceLocation)
                                }
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .background(Color(white: 0.96))
                .clipped()

                // Bottom controls
                HStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.down.right")
                        .foregroundStyle(.secondary)
                    Slider(value: $layerSpacing, in: 0...100)
                        .frame(maxWidth: 200)
                    Spacer()
                    zoomControls
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.bar)
            }
        } else {
            ContentUnavailableView(
                "No View Hierarchy",
                systemImage: "square.3.layers.3d",
                description: Text("Run a script with a View to inspect its hierarchy.")
            )
        }
    }

    // MARK: - Layer Rendering

    private func layerView(node: ViewDescriptor, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected
                      ? Color.blue.opacity(0.2)
                      : Color.white.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.4),
                                lineWidth: isSelected ? 2 : 0.5)
                )
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

            VStack(spacing: 2) {
                Text(node.typeName)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? .blue : .primary)
                if !node.modifiers.isEmpty {
                    Text(node.modifiers.map { ".\($0.name)" }.joined(separator: ""))
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(4)
        }
    }

    // MARK: - Size Calculations

    private func layerWidth(for node: ViewDescriptor, in size: CGSize) -> CGFloat {
        // Scale based on hierarchy depth and type
        let base = size.width * 0.4
        switch node.typeName {
        case "VStack", "HStack", "ZStack", "ScrollView", "Form", "List":
            return base * 0.9
        case "Text", "Image", "Spacer", "Divider":
            return base * 0.5
        default:
            return base * 0.7
        }
    }

    private func layerHeight(for node: ViewDescriptor, in size: CGSize) -> CGFloat {
        let base = size.height * 0.15
        switch node.typeName {
        case "Spacer": return base * 0.3
        case "Divider": return base * 0.2
        default: return base
        }
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation { rotation = max(rotation - 10, 0) }
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            Text("\(Int(rotation))°")
                .font(.caption.monospacedDigit())
                .frame(minWidth: 30)
            Button {
                withAnimation { rotation = min(rotation + 10, 60) }
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }
}
