import LanguageSupport
import RegexBuilder

/// Lantern language configuration for CodeEditorView syntax highlighting.
///
/// Uses regex-based tokenization matching Swift syntax. When Lantern's
/// `classifyTokens()` API is implemented, this can be replaced with a
/// token-based highlighter using the real parser.
extension LanguageConfiguration {

    /// Language configuration for Lantern (Swift subset).
    public static func lantern() -> LanguageConfiguration {
        LanguageConfiguration(
            name: "Lantern",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: stringPattern,
            characterRegex: nil,
            numberRegex: numberPattern,
            singleLineComment: "//",
            nestedComment: (open: "/*", close: "*/"),
            identifierRegex: identifierPattern,
            operatorRegex: operatorPattern,
            reservedIdentifiers: reservedIdentifiers,
            reservedOperators: reservedOperators
        )
    }

    // MARK: - Patterns

    /// String literals including interpolation markers.
    nonisolated(unsafe) private static let stringPattern: Regex<Substring> = #/\"(?:[^\"\\]|\\.)*\"/#

    /// Number literals: decimal, hex, octal, binary, with optional underscores.
    nonisolated(unsafe) private static let numberPattern: Regex<Substring> =
        #/(?:0x[0-9a-fA-F][0-9a-fA-F_]*|0o[0-7][0-7_]*|0b[01][01_]*|[0-9][0-9_]*(?:\.[0-9][0-9_]*)?(?:[eE][+-]?[0-9][0-9_]*)?)/#

    /// Identifiers: standard Swift identifiers plus backtick-escaped and $-prefixed.
    nonisolated(unsafe) private static let identifierPattern: Regex<Substring> =
        #/(?:`[^\s`]+`|\$[0-9]+|[a-zA-Z_][a-zA-Z0-9_]*)/#

    /// Operator characters.
    nonisolated(unsafe) private static let operatorPattern: Regex<Substring> =
        #/[+\-*/%=<>!&|^~?]+|\.\.(?:\.|\<)?/#

    // MARK: - Reserved Words

    private static let reservedIdentifiers: [String] = [
        // Declarations
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
        "func", "import", "init", "inout", "internal", "let", "open", "operator",
        "private", "protocol", "public", "rethrows", "static", "struct",
        "subscript", "typealias", "var",
        // Statements
        "break", "case", "continue", "default", "defer", "do", "else",
        "fallthrough", "for", "guard", "if", "in", "repeat", "return",
        "switch", "where", "while",
        // Expressions & types
        "as", "Any", "catch", "false", "is", "nil", "super", "self", "Self",
        "throw", "throws", "true", "try",
        // Concurrency
        "async", "await", "actor",
        // Context-sensitive
        "some", "any",
        // Property wrappers commonly used in Lantern SwiftUI
        "mutating", "nonmutating", "override", "required", "convenience",
    ]

    private static let reservedOperators: [String] = [
        "->", "=>", "?", "!", ".", "...", "..<",
    ]
}
