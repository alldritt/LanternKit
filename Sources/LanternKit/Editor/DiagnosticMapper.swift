import LanguageSupport
import LanternVM
import LanternCompiler

/// Maps Lantern diagnostics to CodeEditorView messages.
public enum DiagnosticMapper {

    /// Convert compiler diagnostics to CodeEditorView messages.
    public static func map(_ diagnostics: CompilerDiagnostics) -> Set<TextLocated<Message>> {
        Set(diagnostics.diagnostics.map { mapOne($0) })
    }

    /// Convert a single compiler diagnostic.
    public static func map(_ diagnostic: CompilerDiagnostic) -> TextLocated<Message> {
        mapOne(diagnostic)
    }

    /// Convert a runtime error to a CodeEditorView message.
    public static func map(_ error: InterpreterError) -> Set<TextLocated<Message>> {
        let line = error.location.map { Int($0.line) } ?? 1
        let message = Message(
            category: .error,
            length: 1,
            summary: error.message,
            description: nil
        )
        let location = TextLocation(oneBasedLine: line, column: 1)
        return [TextLocated(location: location, entity: message)]
    }

    // MARK: - Private

    private static func mapOne(_ diagnostic: CompilerDiagnostic) -> TextLocated<Message> {
        let category: Message.Category = switch diagnostic.severity {
        case .error: .error
        case .warning: .warning
        case .note: .informational
        }

        let line = diagnostic.location.map { Int($0.line) } ?? 1
        let message = Message(
            category: category,
            length: 1,
            summary: diagnostic.message,
            description: nil
        )
        let location = TextLocation(oneBasedLine: line, column: 1)
        return TextLocated(location: location, entity: message)
    }
}
