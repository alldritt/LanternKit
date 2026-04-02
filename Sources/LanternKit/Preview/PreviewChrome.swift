import SwiftUI

/// Device size presets for the preview canvas.
public enum DevicePreset: String, CaseIterable, Identifiable {
    case iPhoneSE = "iPhone SE"
    case iPhone16 = "iPhone 16"
    case iPhone16Pro = "iPhone 16 Pro Max"
    case iPadMini = "iPad mini"
    case iPad = "iPad"

    public var id: String { rawValue }

    public var size: CGSize {
        switch self {
        case .iPhoneSE: CGSize(width: 375, height: 667)
        case .iPhone16: CGSize(width: 393, height: 852)
        case .iPhone16Pro: CGSize(width: 430, height: 932)
        case .iPadMini: CGSize(width: 744, height: 1133)
        case .iPad: CGSize(width: 820, height: 1180)
        }
    }
}

/// Wraps preview content with device frame and environment controls.
///
/// Provides toggles for color scheme, dynamic type, device size,
/// and layout direction. Applies environment modifiers to the content.
public struct PreviewChrome<Content: View>: View {
    let content: () -> Content

    @State private var colorScheme: ColorScheme = .light
    @State private var dynamicTypeSize: DynamicTypeSize = .large
    @State private var devicePreset: DevicePreset = .iPhone16
    @State private var layoutDirection: LayoutDirection = .leftToRight

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            previewArea
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // Color scheme toggle
            Button {
                colorScheme = colorScheme == .light ? .dark : .light
            } label: {
                Image(systemName: colorScheme == .light
                      ? "sun.max.fill" : "moon.fill")
            }
            .help("Toggle light/dark mode")

            // Device picker
            Picker("Device", selection: $devicePreset) {
                ForEach(DevicePreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .labelsHidden()
            #if os(macOS)
            .pickerStyle(.menu)
            #endif
            .frame(maxWidth: 160)

            // Dynamic type
            Picker("Text Size", selection: $dynamicTypeSize) {
                Text("XS").tag(DynamicTypeSize.xSmall)
                Text("S").tag(DynamicTypeSize.small)
                Text("M").tag(DynamicTypeSize.medium)
                Text("L").tag(DynamicTypeSize.large)
                Text("XL").tag(DynamicTypeSize.xLarge)
                Text("XXL").tag(DynamicTypeSize.xxLarge)
                Text("AX1").tag(DynamicTypeSize.accessibility1)
            }
            .labelsHidden()
            #if os(macOS)
            .pickerStyle(.menu)
            #endif
            .frame(maxWidth: 80)

            // Layout direction toggle
            Button {
                layoutDirection = layoutDirection == .leftToRight
                    ? .rightToLeft : .leftToRight
            } label: {
                Image(systemName: layoutDirection == .leftToRight
                      ? "text.alignleft" : "text.alignright")
            }
            .help("Toggle layout direction (LTR/RTL)")

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var previewArea: some View {
        ScrollView([.horizontal, .vertical]) {
            content()
                .environment(\.colorScheme, colorScheme)
                .environment(\.dynamicTypeSize, dynamicTypeSize)
                .environment(\.layoutDirection, layoutDirection)
                .frame(width: devicePreset.size.width,
                       height: devicePreset.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 4)
                .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.9))
    }
}
