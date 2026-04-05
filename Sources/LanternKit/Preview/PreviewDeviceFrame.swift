import SwiftUI

/// Renders a single device frame with environment modifiers, safe area insets,
/// and device chrome (Dynamic Island) applied.
///
/// Used both for single-preview mode and as individual cells in the variants grid.
/// An optional label is displayed beneath the frame (e.g. "Dark", "X Small").
///
public struct PreviewDeviceFrame<Content: View>: View {
    let devicePreset: DevicePreset
    let colorScheme: ColorScheme
    let dynamicTypeSize: DynamicTypeSize
    let layoutDirection: LayoutDirection
    let orientation: PreviewOrientation
    let label: String?
    @ViewBuilder let content: () -> Content

    public init(devicePreset: DevicePreset,
                colorScheme: ColorScheme = .light,
                dynamicTypeSize: DynamicTypeSize = .large,
                layoutDirection: LayoutDirection = .leftToRight,
                orientation: PreviewOrientation = .portrait,
                label: String? = nil,
                @ViewBuilder content: @escaping () -> Content)
    {
        self.devicePreset = devicePreset
        self.colorScheme = colorScheme
        self.dynamicTypeSize = dynamicTypeSize
        self.layoutDirection = layoutDirection
        self.orientation = orientation
        self.label = label
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 6) {
            deviceFrame
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private var deviceFrame: some View {
        let insets = effectiveInsets

        return ZStack {
            // Background
            RoundedRectangle(cornerRadius: devicePreset.cornerRadius)
                .fill(colorScheme == .dark ? Color.black : Color.white)

            // Content with safe area padding
            VStack(spacing: 0) {
                content()
                    .environment(\.colorScheme, colorScheme)
                    .environment(\.dynamicTypeSize, dynamicTypeSize)
                    .environment(\.layoutDirection, layoutDirection)
            }
            .padding(.top, insets.top)
            .padding(.bottom, insets.bottom)
            .padding(.leading, insets.leading)
            .padding(.trailing, insets.trailing)

            // Device chrome overlay (status bar area, Dynamic Island, home indicator)
            deviceChromeOverlay
        }
        .frame(width: effectiveSize.width, height: effectiveSize.height)
        .clipShape(RoundedRectangle(cornerRadius: devicePreset.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: devicePreset.cornerRadius)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    // MARK: - Device Chrome Overlay

    @ViewBuilder
    private var deviceChromeOverlay: some View {
        let fgColor = colorScheme == .dark ? Color.white : Color.black

        VStack {
            // Top: status bar + Dynamic Island
            ZStack {
                // Status bar: time left, icons right
                HStack {
                    Text("9:41")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(fgColor)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "cellularbars")
                        Image(systemName: "wifi")
                        Image(systemName: "battery.75percent")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(fgColor)
                }
                .padding(.horizontal, 20)

                // Dynamic Island: centered independently
                if devicePreset.hasDynamicIsland {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: devicePreset.dynamicIslandSize.width,
                               height: devicePreset.dynamicIslandSize.height)
                }
            }
            .padding(.top, devicePreset.hasDynamicIsland ? 14 : 4)

            Spacer()

            // Bottom: home indicator
            if effectiveInsets.bottom > 0 && devicePreset.isPhone && devicePreset != .iPhoneSE {
                Capsule()
                    .fill(fgColor.opacity(0.3))
                    .frame(width: 134, height: 5)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Geometry

    private var effectiveSize: CGSize {
        let base = devicePreset.size
        return orientation == .landscape
            ? CGSize(width: base.height, height: base.width)
            : base
    }

    private var effectiveInsets: EdgeInsets {
        let base = devicePreset.safeAreaInsets
        if orientation == .landscape {
            // In landscape, top/bottom swap and side insets appear
            return EdgeInsets(
                top: base.leading,
                leading: base.top,
                bottom: base.trailing,
                trailing: base.bottom
            )
        }
        return base
    }
}
