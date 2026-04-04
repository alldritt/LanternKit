# LanternKit

A library of SwiftUI views and controllers for building [Lantern](https://github.com/alldritt/Lantern) development tools. Provides a source editor, console, live SwiftUI preview, debug panels, and a Code Bubbles-style visual debugger -- all as independent, composable components.

LanternKit is the UI layer behind [Wick](https://github.com/alldritt/Wick), but any application embedding the Lantern interpreter can use these components.

## Requirements

- macOS 15+ / iOS 18+
- Swift 6.0
- [Lantern](https://github.com/alldritt/Lantern) interpreter
- [CodeEditorView](https://github.com/mchakravarty/CodeEditorView)

## Installation

Add LanternKit as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/alldritt/LanternKit.git", branch: "main"),
]
```

Then add `"LanternKit"` to your target's dependencies.

## Architecture

LanternKit sits between the Lantern interpreter and your application:

```
Your App ──depends on──> LanternKit ──depends on──> Lantern
                                     ──depends on──> CodeEditorView
```

**Design principle: every view is independently usable.** You can embed the editor without the debugger, or the preview canvas without the editor. Views accept their dependencies through initializer parameters, not environment objects or singletons.

## Components

### SessionController

The central `@Observable` controller that manages the compile/run/debug lifecycle. Create one per document.

```swift
import LanternKit

struct DocumentView: View {
    @Binding var document: MyDocument
    @State private var session = SessionController()

    var body: some View {
        VStack {
            // ... your layout using session ...
        }
    }
}
```

**Key API:**

```swift
// Run to completion (breakpoints are honoured)
session.run(source: sourceCode)

// Step over one statement (compiles if needed, then pauses)
session.stepOver(source: sourceCode)

// Step into / step out / resume / pause
session.stepInto(source: sourceCode)
session.stepOut()
session.resume()
session.pauseExecution()

// Stop and reset
session.stop()

// State observation
session.state        // .idle, .compiling, .running, .paused, .finished, .error
session.consoleOutput
session.diagnostics
session.debugSession // always-on DebugSession
session.previewView  // ViewStub if a View type is detected
```

### LanternEditorView

Source editor with Lantern syntax highlighting and inline diagnostic display. Wraps [CodeEditorView](https://github.com/mchakravarty/CodeEditorView).

```swift
import CodeEditorView
import LanguageSupport

@State private var messages: Set<TextLocated<Message>> = []
@State private var position = CodeEditor.Position()

LanternEditorView(
    source: $document.source,
    messages: $messages,
    position: $position
)
```

Use `DiagnosticMapper` to convert compiler/runtime errors to editor messages:

```swift
if let diags = session.diagnostics {
    messages = DiagnosticMapper.map(diags)
}
```

### LanternConsoleView

Program output display with auto-scroll.

```swift
LanternConsoleView(output: session.consoleOutput)
```

### PreviewCanvasView

Live SwiftUI preview of interpreted views. Shows the `ViewStub` produced by `SessionController` when the program defines a `View` type.

```swift
PreviewCanvasView(
    previewView: session.previewView,
    detectedTypeName: session.detectedViewTypeName,
    hasError: session.diagnostics != nil
)
```

The preview is wrapped in `PreviewChrome`, which provides device frame presets and environment controls (color scheme, dynamic type, device size, layout direction).

### DebugSession

Always-on debugger wrapper. Created automatically by `SessionController`. Provides call stack, variables, breakpoint management, and expression evaluation.

```swift
let dbg = session.debugSession

// Breakpoints
dbg.toggleBreakpoint(file: "<input>", line: 5)
dbg.addBreakpoint(file: "<input>", line: 10, condition: "i > 5")
dbg.isBreakOnExceptions = true

// Inspection (populated when paused)
dbg.callStack         // [FrameInfo]
dbg.currentLocals     // [VariableInfo]
dbg.currentCaptures   // [VariableInfo]
dbg.currentGlobals    // [VariableInfo]
dbg.pausedLocation    // SourceLocation?
dbg.isPaused          // Bool

// Expression evaluation (when paused)
let result = dbg.evaluate(expression: "items.count")
```

### CallStackPanel

Displays the call stack with frame selection.

```swift
CallStackPanel(
    frames: dbg.callStack,
    selectedFrame: dbg.selectedFrame,
    onSelectFrame: { dbg.selectFrame($0) }
)
```

### VariablesPanel

Displays locals, captures, and globals with expandable compound values using `Value.debugChildren`.

```swift
VariablesPanel(
    locals: dbg.currentLocals,
    captures: dbg.currentCaptures,
    globals: dbg.currentGlobals
)
```

### DebugToolbar

Execution control buttons: Continue, Pause, Step Over, Step Into, Step Out.

```swift
DebugToolbar(
    isPaused: dbg.isPaused,
    isDebugging: true,
    onContinue: { session.resume() },
    onPause: { session.pauseExecution() },
    onStepOver: { session.stepOver() },
    onStepInto: { session.stepInto() },
    onStepOut: { session.stepOut() }
)
```

### DebugREPLView

Expression evaluator with scrollable history. Active when the debugger is paused.

```swift
DebugREPLView(
    isPaused: dbg.isPaused,
    onEvaluate: { dbg.evaluate(expression: $0) }
)
```

### DebugCanvasView

Code Bubbles-style pannable, zoomable canvas. Each call frame appears as a bubble with function name, source context, and local variables. Bubbles are connected by bezier curves showing the call path.

```swift
DebugCanvasView(
    canvas: dbg.canvasModel,
    onSelectBubble: { dbg.selectFrame($0.frameIndex) }
)
```

Supports pinch-to-zoom, drag-to-pan, and bubble repositioning. Bubbles auto-layout left-to-right on pause and dim on resume.

### ViewHierarchyInspector

Tree view of the `ViewDescriptor` hierarchy for inspecting interpreted SwiftUI views.

```swift
ViewHierarchyInspector(
    descriptor: session.viewDescriptor,
    onSelectNode: { location in
        // Navigate editor to source location
    }
)
```

## Putting It Together

Here's a minimal Lantern IDE using LanternKit:

```swift
import SwiftUI
import LanternKit
import CodeEditorView
import LanguageSupport

struct MiniIDE: View {
    @State private var source = "print(\"Hello!\")"
    @State private var session = SessionController()
    @State private var messages: Set<TextLocated<Message>> = []
    @State private var position = CodeEditor.Position()

    var body: some View {
        VStack(spacing: 0) {
            // Editor
            LanternEditorView(
                source: $source,
                messages: $messages,
                position: $position
            )

            Divider()

            // Console
            LanternConsoleView(output: session.consoleOutput)
                .frame(height: 150)
        }
        .toolbar {
            Button("Run") { session.run(source: source) }
            Button("Step") { session.stepOver(source: source) }
            Button("Stop") { session.stop() }
        }
        .onChange(of: session.state) {
            if let diags = session.diagnostics {
                messages = DiagnosticMapper.map(diags)
            } else {
                messages = []
            }
        }
    }
}
```

## File Structure

```
Sources/LanternKit/
    Editor/
        LanternEditorView       CodeEditor with Lantern syntax highlighting
        LanternLanguage          LanguageConfiguration for Lantern
        DiagnosticMapper         Compiler/runtime errors to editor messages
    Console/
        LanternConsoleView       Program output with auto-scroll
        DebugREPLView            Expression evaluator when paused
    Preview/
        PreviewCanvasView        Live SwiftUI preview host
        PreviewChrome            Device frame and environment controls
        ViewHierarchyInspector   ViewDescriptor tree view
    Debugger/
        CallStackPanel           Call stack with frame selection
        VariablesPanel           Locals/captures/globals display
        DebugToolbar             Execution control buttons
    Canvas/
        DebugCanvasView          Pannable/zoomable bubble canvas
        BubbleView               Individual call frame bubble
        BubbleModel              Canvas data model
        BubbleLayoutEngine       Automatic bubble positioning
        ConnectionLinesView      Bezier curve call-path arrows
    Session/
        SessionController        Compile/run/debug lifecycle
        DebugSession             Observable debugger wrapper
```

## License

MIT
