import SwiftUI

/// Generates multiple device frames in a grid, each with different environment settings
/// based on the active variant mode.
///
public struct PreviewVariantsGrid<Content: View>: View {
    let state: PreviewCanvasState
    @ViewBuilder let content: () -> Content

    public init(state: PreviewCanvasState, @ViewBuilder content: @escaping () -> Content) {
        self.state = state
        self.content = content
    }

    public var body: some View {
        switch state.variantMode {
        case .none:
            // Single frame — shouldn't get here, but handle gracefully
            PreviewDeviceFrame(
                devicePreset: state.devicePreset,
                colorScheme: state.colorScheme,
                dynamicTypeSize: state.dynamicTypeSize,
                layoutDirection: state.layoutDirection,
                orientation: state.orientation
            ) { content() }

        case .colorScheme:
            twoUpLayout {
                PreviewDeviceFrame(
                    devicePreset: state.devicePreset,
                    colorScheme: .light,
                    dynamicTypeSize: state.dynamicTypeSize,
                    layoutDirection: state.layoutDirection,
                    orientation: state.orientation,
                    label: "Light"
                ) { content() }

                PreviewDeviceFrame(
                    devicePreset: state.devicePreset,
                    colorScheme: .dark,
                    dynamicTypeSize: state.dynamicTypeSize,
                    layoutDirection: state.layoutDirection,
                    orientation: state.orientation,
                    label: "Dark"
                ) { content() }
            }

        case .orientation:
            twoUpLayout {
                PreviewDeviceFrame(
                    devicePreset: state.devicePreset,
                    colorScheme: state.colorScheme,
                    dynamicTypeSize: state.dynamicTypeSize,
                    layoutDirection: state.layoutDirection,
                    orientation: .portrait,
                    label: "Portrait"
                ) { content() }

                PreviewDeviceFrame(
                    devicePreset: state.devicePreset,
                    colorScheme: state.colorScheme,
                    dynamicTypeSize: state.dynamicTypeSize,
                    layoutDirection: state.layoutDirection,
                    orientation: .landscape,
                    label: "Landscape"
                ) { content() }
            }

        case .dynamicType:
            dynamicTypeGrid
        }
    }

    // MARK: - Layouts

    private func twoUpLayout<V: View>(@ViewBuilder _ views: () -> V) -> some View {
        HStack(alignment: .top, spacing: 24) {
            views()
        }
    }

    private var dynamicTypeGrid: some View {
        let sizes: [(DynamicTypeSize, String)] = [
            (.xSmall, "X Small"),
            (.small, "Small"),
            (.medium, "Medium"),
            (.large, "Large (Default)"),
            (.xLarge, "X Large"),
            (.xxLarge, "XX Large"),
            (.xxxLarge, "XXX Large"),
            (.accessibility1, "Accessibility 1"),
            (.accessibility2, "Accessibility 2"),
            (.accessibility3, "Accessibility 3"),
        ]

        // Fixed 3-column grid (matching Xcode's layout)
        let columns = Array(repeating: GridItem(.fixed(state.devicePreset.size.width + 20),
                                                alignment: .top),
                            count: 3)

        return LazyVGrid(columns: columns, spacing: 24) {
            ForEach(sizes, id: \.0) { size, label in
                PreviewDeviceFrame(
                    devicePreset: state.devicePreset,
                    colorScheme: state.colorScheme,
                    dynamicTypeSize: size,
                    layoutDirection: state.layoutDirection,
                    orientation: state.orientation,
                    label: label
                ) { content() }
            }
        }
    }
}
