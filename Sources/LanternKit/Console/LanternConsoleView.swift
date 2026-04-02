import SwiftUI

/// Displays program output with auto-scroll to bottom.
///
/// Monospaced font on a dark background. Scrolls to the bottom
/// whenever new output is appended.
public struct LanternConsoleView: View {
    let output: String

    public init(output: String) {
        self.output = output
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(output.isEmpty ? " " : output)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .id("consoleBottom")
            }
            .onChange(of: output) {
                withAnimation {
                    proxy.scrollTo("consoleBottom", anchor: .bottom)
                }
            }
        }
        .background(.black.opacity(0.85))
        .foregroundStyle(.green)
    }
}
