import CodeEditorView
import LanternDebugger
import LanternVM

/// Maps between LanternDebugger domain types and CodeEditorView gutter annotation types.
///
public enum BreakpointMapper {

    /// Convert debugger breakpoints to gutter breakpoint annotations.
    ///
    /// Only line breakpoints are mapped; other kinds (watchpoints, exception, host call) are not
    /// displayed in the gutter.
    ///
    public static func mapBreakpoints(_ breakpoints: [Breakpoint]) -> [GutterBreakpoint] {
        breakpoints.compactMap { bp in
            guard case .line(_, let line) = bp.kind else { return nil }
            return GutterBreakpoint(id: bp.id,
                                    line: line,
                                    isEnabled: bp.isEnabled,
                                    hasCondition: bp.condition != nil)
        }
    }

    /// Build stack frame annotations from the paused location and call stack.
    ///
    /// The paused location (depth 0, top frame) always comes from `pausedLocation`,
    /// which is set even at the top level of a script where there are no call stack frames.
    /// Additional caller frames come from `callStack` at depth 1+.
    ///
    public static func mapPausedState(pausedLocation: SourceLocation?,
                                      callStack: [FrameInfo]) -> [GutterStackFrame]
    {
        var result: [GutterStackFrame] = []

        // Current statement indicator from pausedLocation (always present when paused)
        if let loc = pausedLocation, loc.line > 0 {
            result.append(GutterStackFrame(line: Int(loc.line), depth: 0))
        }

        // Caller frames from the call stack (depth 1+, skipping the top frame
        // since pausedLocation already covers it)
        for (index, frame) in callStack.dropFirst().enumerated() {
            guard let loc = frame.sourceLocation, loc.line > 0 else { continue }
            result.append(GutterStackFrame(line: Int(loc.line), depth: index + 1))
        }

        return result
    }
}
