import SwiftUI

// MARK: - Preview Configuration Types

/// Device size presets for the preview canvas, grouped by category.
///
public enum DevicePreset: String, CaseIterable, Identifiable {
    // iPhone
    case iPhoneSE       = "iPhone SE"
    case iPhone16       = "iPhone 16"
    case iPhone16Pro    = "iPhone 16 Pro"
    case iPhone16ProMax = "iPhone 16 Pro Max"

    // iPad
    case iPadMini       = "iPad mini"
    case iPad           = "iPad"
    case iPadAir        = "iPad Air"
    case iPadPro11      = "iPad Pro 11\""
    case iPadPro13      = "iPad Pro 13\""

    public var id: String { rawValue }

    public var size: CGSize {
        switch self {
        case .iPhoneSE:       CGSize(width: 375, height: 667)
        case .iPhone16:       CGSize(width: 393, height: 852)
        case .iPhone16Pro:    CGSize(width: 402, height: 874)
        case .iPhone16ProMax: CGSize(width: 430, height: 932)
        case .iPadMini:       CGSize(width: 744, height: 1133)
        case .iPad:           CGSize(width: 820, height: 1180)
        case .iPadAir:        CGSize(width: 820, height: 1180)
        case .iPadPro11:      CGSize(width: 834, height: 1194)
        case .iPadPro13:      CGSize(width: 1024, height: 1366)
        }
    }

    public var cornerRadius: CGFloat {
        switch self {
        case .iPhoneSE: 12
        default: 20
        }
    }

    /// Safe area insets for this device (top, leading, bottom, trailing).
    public var safeAreaInsets: EdgeInsets {
        switch self {
        case .iPhoneSE:       EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)
        case .iPhone16:       EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        case .iPhone16Pro:    EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        case .iPhone16ProMax: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        case .iPadMini:       EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)
        case .iPad:           EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)
        case .iPadAir:        EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)
        case .iPadPro11:      EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)
        case .iPadPro13:      EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)
        }
    }

    /// Whether this device has a Dynamic Island (or notch).
    public var hasDynamicIsland: Bool {
        switch self {
        case .iPhone16, .iPhone16Pro, .iPhone16ProMax: true
        default: false
        }
    }

    /// Width of the Dynamic Island pill shape.
    public var dynamicIslandSize: CGSize {
        switch self {
        case .iPhone16:       CGSize(width: 126, height: 37)
        case .iPhone16Pro:    CGSize(width: 126, height: 37)
        case .iPhone16ProMax: CGSize(width: 126, height: 37)
        default:              .zero
        }
    }

    public var isPhone: Bool {
        switch self {
        case .iPhoneSE, .iPhone16, .iPhone16Pro, .iPhone16ProMax: true
        default: false
        }
    }

    /// Grouped presets for display in menus.
    public static var phonePresets: [DevicePreset] {
        [.iPhoneSE, .iPhone16, .iPhone16Pro, .iPhone16ProMax]
    }

    public static var padPresets: [DevicePreset] {
        [.iPadMini, .iPad, .iPadAir, .iPadPro11, .iPadPro13]
    }
}

/// Which variant mode is active in the preview canvas.
///
public enum PreviewVariantMode: String, CaseIterable, Identifiable {
    case none         = "No Variants"
    case colorScheme  = "Color Scheme Variants"
    case orientation  = "Orientation Variants"
    case dynamicType  = "Dynamic Type Variants"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .none:        "rectangle"
        case .colorScheme: "circle.lefthalf.filled"
        case .orientation: "rectangle.landscape.rotate"
        case .dynamicType: "textformat.size"
        }
    }
}

/// Preview orientation.
///
public enum PreviewOrientation: String, CaseIterable {
    case portrait
    case landscape
}

// MARK: - Canvas State

/// Observable state for the preview canvas, shared between the toolbar and the canvas area.
///
@Observable
@MainActor
public final class PreviewCanvasState {
    public var devicePreset: DevicePreset = .iPhone16
    public var variantMode: PreviewVariantMode = .none
    public var colorScheme: ColorScheme = .light
    public var dynamicTypeSize: DynamicTypeSize = .large
    public var layoutDirection: LayoutDirection = .leftToRight
    public var orientation: PreviewOrientation = .portrait
    public var scale: CGFloat = 1.0
    public var panOffset: CGSize = .zero

    public init() {}

    /// The effective device size accounting for orientation.
    public var effectiveDeviceSize: CGSize {
        let base = devicePreset.size
        return orientation == .landscape
            ? CGSize(width: base.height, height: base.width)
            : base
    }

    /// Estimated total content size accounting for variant mode.
    public var estimatedContentSize: CGSize {
        let device = effectiveDeviceSize
        let spacing: CGFloat = 24
        let labelHeight: CGFloat = 30

        switch variantMode {
        case .none:
            return device

        case .colorScheme, .orientation:
            // Two frames side by side
            return CGSize(width: device.width * 2 + spacing,
                          height: device.height + labelHeight)

        case .dynamicType:
            // Grid: estimate 3 columns
            let columns = 3
            let rows = (10 + columns - 1) / columns  // 10 dynamic type sizes
            return CGSize(width: device.width * CGFloat(columns) + spacing * CGFloat(columns - 1),
                          height: (device.height + labelHeight + spacing) * CGFloat(rows))
        }
    }

    // MARK: - Zoom

    public func zoomIn() {
        scale = min(scale * 1.25, 4.0)
    }

    public func zoomOut() {
        scale = max(scale / 1.25, 0.1)
    }

    public func zoomToFit(availableSize: CGSize) {
        let contentSize = estimatedContentSize
        guard contentSize.width > 0, contentSize.height > 0 else { return }
        let padding: CGFloat = 60
        let scaleX = (availableSize.width - padding) / contentSize.width
        let scaleY = (availableSize.height - padding) / contentSize.height
        scale = min(scaleX, scaleY, 1.0)
        panOffset = .zero
    }

    public func zoomToFill(availableWidth: CGFloat) {
        let contentWidth = estimatedContentSize.width
        guard contentWidth > 0 else { return }
        let padding: CGFloat = 40
        scale = (availableWidth - padding) / contentWidth
        panOffset = .zero
    }

    public var zoomPercentage: Int {
        Int(scale * 100)
    }
}
