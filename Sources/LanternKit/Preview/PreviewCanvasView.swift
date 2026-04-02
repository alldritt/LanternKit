import SwiftUI
import LanternSwiftUI

/// Hosts the live SwiftUI preview of an interpreted view.
///
/// Shows the ViewStub produced by the SessionController inside a PreviewChrome.
/// When no preview is available, shows a placeholder with detection status.
public struct PreviewCanvasView: View {
    let previewView: ViewStub?
    let detectedTypeName: String?
    let hasError: Bool

    public init(
        previewView: ViewStub?,
        detectedTypeName: String?,
        hasError: Bool = false
    ) {
        self.previewView = previewView
        self.detectedTypeName = detectedTypeName
        self.hasError = hasError
    }

    public var body: some View {
        Group {
            if let previewView {
                PreviewChrome {
                    AnyView(previewView)
                }
                .opacity(hasError ? 0.5 : 1.0)
                .overlay(alignment: .topTrailing) {
                    if hasError {
                        outdatedBadge
                    }
                }
            } else if let typeName = detectedTypeName {
                pendingPreview(typeName: typeName)
            } else {
                noPreview
            }
        }
    }

    private var noPreview: some View {
        ContentUnavailableView(
            "No Preview",
            systemImage: "rectangle.dashed",
            description: Text("Run a script that defines a View to see a live preview.")
        )
    }

    private func pendingPreview(typeName: String) -> some View {
        ContentUnavailableView {
            Label(typeName, systemImage: "rectangle.dashed")
        } description: {
            Text("View type detected. Preview rendering requires Lantern view evaluation support.")
        }
    }

    private var outdatedBadge: some View {
        Text("Outdated")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.orange, in: Capsule())
            .padding(8)
    }
}
