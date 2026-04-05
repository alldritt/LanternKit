import SwiftUI

/// Bottom toolbar for the preview canvas with device selector, variant menu, and zoom controls.
///
public struct PreviewToolbar: View {
    @Bindable var state: PreviewCanvasState

    /// Available size of the canvas area, used for zoom-to-fit/fill calculations.
    var availableSize: CGSize = .zero

    public init(state: PreviewCanvasState, availableSize: CGSize = .zero) {
        self.state = state
        self.availableSize = availableSize
    }

    public var body: some View {
        HStack(spacing: 8) {
            deviceMenu
            variantPicker
            Spacer()
            zoomControls
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

    // MARK: - Device Menu

    private var deviceMenu: some View {
        Menu {
            Section("iPhone") {
                ForEach(DevicePreset.phonePresets) { preset in
                    Button {
                        state.devicePreset = preset
                    } label: {
                        HStack {
                            Text(preset.rawValue)
                            if state.devicePreset == preset {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Section("iPad") {
                ForEach(DevicePreset.padPresets) { preset in
                    Button {
                        state.devicePreset = preset
                    } label: {
                        HStack {
                            Text(preset.rawValue)
                            if state.devicePreset == preset {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: state.devicePreset.isPhone ? "iphone" : "ipad")
                Text(state.devicePreset.rawValue)
                    .lineLimit(1)
            }
            .font(.caption)
        }
        .menuIndicator(.hidden)
    }

    // MARK: - Variant Menu

    private var variantPicker: some View {
        Picker("Variants", selection: $state.variantMode) {
            ForEach(PreviewVariantMode.allCases) { mode in
                Image(systemName: mode.systemImage)
                    .help(mode.rawValue)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 160)
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button {
                state.zoomToFit(availableSize: availableSize)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Zoom to Fit")

            Button {
                state.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")

            Text("\(state.zoomPercentage)%")
                .font(.caption.monospacedDigit())
                .frame(minWidth: 36)

            Button {
                state.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")

            Button {
                state.zoomToFill(availableWidth: availableSize.width)
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .help("Zoom to Fill")
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }
}
