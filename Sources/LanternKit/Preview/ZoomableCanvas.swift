import SwiftUI

/// A container that supports zoom on its content within a scrollable area.
///
/// Uses `scaleEffect` for visual scaling and wraps content in a frame sized to the
/// scaled dimensions so the ScrollView's content area matches what's actually visible.
///
public struct ZoomableCanvas<Content: View>: View {
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @ViewBuilder let content: () -> Content

    /// The unscaled content size, used to compute the scaled frame.
    var contentSize: CGSize = .zero

    public init(scale: Binding<CGFloat>,
                offset: Binding<CGSize>,
                contentSize: CGSize = .zero,
                @ViewBuilder content: @escaping () -> Content)
    {
        self._scale = scale
        self._offset = offset
        self.contentSize = contentSize
        self.content = content
    }

    public var body: some View {
        ScrollView([.horizontal, .vertical]) {
            content()
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: max(contentSize.width * scale, 1),
                       height: max(contentSize.height * scale, 1),
                       alignment: .topLeading)
                .padding(20 * scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.94))
    }
}
