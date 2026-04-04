import SwiftUI
import CodeEditorView
import LanguageSupport

/// Source editor with Lantern syntax highlighting and inline diagnostic display.
///
/// Wraps CodeEditorView's `CodeEditor` with the Lantern language configuration
/// pre-applied. Consumers bind source text, cursor position, and diagnostic messages.
public struct LanternEditorView: View {
    @Binding var source: String
    @Binding var messages: Set<TextLocated<Message>>
    @Binding var position: CodeEditor.Position

    var breakpoints: [GutterBreakpoint]
    var stackFrames: [GutterStackFrame]
    var breakpointActions: GutterBreakpointActions

    public init(
        source: Binding<String>,
        messages: Binding<Set<TextLocated<Message>>>,
        position: Binding<CodeEditor.Position>,
        breakpoints: [GutterBreakpoint] = [],
        stackFrames: [GutterStackFrame] = [],
        breakpointActions: GutterBreakpointActions = .none
    ) {
        self._source = source
        self._messages = messages
        self._position = position
        self.breakpoints = breakpoints
        self.stackFrames = stackFrames
        self.breakpointActions = breakpointActions
    }

    public var body: some View {
        CodeEditor(
            text: $source,
            position: $position,
            messages: $messages,
            language: .lantern()
        )
        .environment(\.codeEditorBreakpoints, breakpoints)
        .environment(\.codeEditorStackFrames, stackFrames)
        .environment(\.codeEditorBreakpointActions, breakpointActions)
        #if os(macOS)
        .environment(\.codeEditorLayoutConfiguration,
                      CodeEditor.LayoutConfiguration(showMinimap: true, wrapText: true))
        #endif
    }
}
