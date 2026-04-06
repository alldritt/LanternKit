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
                                .font(Font.system(size: 15))
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
                                .font(Font.system(size: 15))
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
        .fixedSize()
        .labelsHidden()
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button {
                state.zoomToFit(availableSize: availableSize)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(Font.system(size: 15))
            }
            .help("Zoom to Fit")
            .padding(.horizontal, 4)

            Button {
                state.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(Font.system(size: 15))
            }
            .help("Zoom Out")
            .padding(.horizontal, 4)

            Button {
                state.zoomActualSize()
            } label: {
                Image(systemName: "1.magnifyingglass")
                    .font(Font.system(size: 15))
            }
            .help("Actual Size")
            .padding(.horizontal, 4)

            Text("\(state.zoomPercentage)%")
                .font(Font.system(size: 13))
                .frame(minWidth: 36)
                .padding(.horizontal, 4)

            Button {
                state.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(Font.system(size: 15))
            }
            .help("Zoom In")
            .padding(.horizontal, 4)

            Button {
                state.zoomToFill(availableWidth: availableSize.width)
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(Font.system(size: 15))
            }
            .help("Zoom to Fill")
            .padding(.horizontal, 4)
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }
}
