import SwiftUI
import LanternVM
import LanternSwiftUI

/// Displays the result of script execution in the preview panel.
///
/// The preview model is simple: whatever value the script produces is displayed.
/// - SwiftUI views (ViewBox host objects) are rendered live inside PreviewChrome
/// - Scalar values (strings, numbers, bools) are shown as formatted text
/// - Void/nil results show a "no result" placeholder
/// - Errors show the error message
public struct PreviewCanvasView: View {
    let result: Value?
    let error: String?
    /// Optional session reference for reading view descriptor on demand (only in hierarchy mode).
    /// Kept as an optional to avoid making SessionController a hard dependency of this view.
    var session: SessionController?
    let onSelectNode: (SourceLocation) -> Void

    @State private var canvasState = PreviewCanvasState()

    public init(result: Value?,
                error: String? = nil,
                session: SessionController? = nil,
                onSelectNode: @escaping (SourceLocation) -> Void = { _ in })
    {
        self.result = result
        self.error = error
        self.session = session
        self.onSelectNode = onSelectNode
    }

    public var body: some View {
        Group {
            switch canvasState.mode {
            case .preview:
                if let error {
                    errorView(error)
                } else if let result {
                    resultView(result)
                } else {
                    noResult
                }

            case .hierarchy:
                ViewHierarchyInspector(
                    descriptor: session?.viewDescriptor,
                    onSelectNode: onSelectNode
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Mode", selection: $canvasState.mode) {
                    Image(systemName: "rectangle.dashed")
                        .help("Preview")
                        .tag(PreviewMode.preview)
                    Image(systemName: "square.3.layers.3d")
                        .help("View Hierarchy")
                        .tag(PreviewMode.hierarchy)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Result Display

    @ViewBuilder
    private func resultView(_ value: Value) -> some View {
        switch value {
        case .hostObject(let ref) where ref.object is ViewBox:
            // SwiftUI view — render live in zoomable device canvas
            viewPreview { (ref.object as! ViewBox).view }

        case .void, .nil_:
            noResult

        case .string(let s):
            scalarView(s, typeName: "String", icon: "text.quote")

        case .int(let n):
            scalarView("\(n)", typeName: "Int", icon: "number")

        case .double(let d):
            scalarView("\(d)", typeName: "Double", icon: "number")

        case .bool(let b):
            scalarView("\(b)", typeName: "Bool", icon: b ? "checkmark.circle" : "xmark.circle")

        case .array(let arr):
            scalarView("\(arr.count) elements", typeName: "Array", icon: "list.bullet")

        case .dictionary(let dict):
            scalarView("\(dict.count) entries", typeName: "Dictionary", icon: "list.bullet.indent")

        case .instance(let ref):
            scalarView(ref.typeName, typeName: "Instance", icon: "cube")

        default:
            scalarView(value.description, typeName: value.typeName, icon: "square.and.pencil")
        }
    }

    // MARK: - View Preview Canvas

    @State private var canvasSize: CGSize = .zero

    private func viewPreview<V: View>(@ViewBuilder content: @escaping () -> V) -> some View {
        VStack(spacing: 0) {
            ZoomableCanvas(scale: $canvasState.scale, offset: $canvasState.panOffset,
                          contentSize: canvasState.estimatedContentSize) {
                if canvasState.variantMode == .none {
                    PreviewDeviceFrame(
                        devicePreset: canvasState.devicePreset,
                        colorScheme: canvasState.colorScheme,
                        dynamicTypeSize: canvasState.dynamicTypeSize,
                        layoutDirection: canvasState.layoutDirection,
                        orientation: canvasState.orientation
                    ) { content() }
                } else {
                    PreviewVariantsGrid(state: canvasState) { content() }
                }
            }
            .onGeometryChange(for: CGSize.self) { geo in geo.size } action: { newSize in
                if canvasSize == .zero {
                    // Initial layout — auto-fit
                    canvasState.zoomToFit(availableSize: newSize)
                }
                canvasSize = newSize
            }
            .onChange(of: canvasState.variantMode) {
                canvasState.zoomToFit(availableSize: canvasSize)
            }
            .onChange(of: canvasState.devicePreset) {
                canvasState.zoomToFit(availableSize: canvasSize)
            }
            Divider()
            PreviewToolbar(state: canvasState, availableSize: canvasSize)
        }
    }

    // MARK: - Subviews

    private func scalarView(_ text: String, typeName: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(.primary)
            Text(typeName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.95))
    }

    private var noResult: some View {
        ContentUnavailableView(
            "No Result",
            systemImage: "rectangle.dashed",
            description: Text("Run a script to see its result here.\nThe last expression value is displayed.")
        )
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text(message)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.95))
    }
}
