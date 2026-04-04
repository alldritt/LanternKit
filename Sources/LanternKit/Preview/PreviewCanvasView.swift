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

    public init(result: Value?, error: String? = nil) {
        self.result = result
        self.error = error
    }

    public var body: some View {
        Group {
            if let error {
                errorView(error)
            } else if let result {
                resultView(result)
            } else {
                noResult
            }
        }
    }

    // MARK: - Result Display

    @ViewBuilder
    private func resultView(_ value: Value) -> some View {
        switch value {
        case .hostObject(let ref) where ref.object is ViewBox:
            // SwiftUI view — render live in device chrome
            PreviewChrome {
                (ref.object as! ViewBox).view
            }

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
