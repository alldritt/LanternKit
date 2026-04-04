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

    /// Convert debugger call stack frames to gutter stack frame annotations.
    ///
    /// Frames without a source location or with line 0 are filtered out.
    ///
    public static func mapStackFrames(_ frames: [FrameInfo]) -> [GutterStackFrame] {
        frames.enumerated().compactMap { (index, frame) in
            guard let loc = frame.sourceLocation, loc.line > 0 else { return nil }
            return GutterStackFrame(line: Int(loc.line), depth: index)
        }
    }
}
