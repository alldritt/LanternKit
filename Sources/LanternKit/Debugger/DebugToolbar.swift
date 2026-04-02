import SwiftUI

/// Debug execution controls: Continue, Pause, Step Over/Into/Out.
///
/// Accepts callbacks for each action. Enables/disables buttons
/// based on the paused state.
public struct DebugToolbar: View {
    let isPaused: Bool
    let isDebugging: Bool
    let onContinue: () -> Void
    let onPause: () -> Void
    let onStepOver: () -> Void
    let onStepInto: () -> Void
    let onStepOut: () -> Void

    public init(
        isPaused: Bool,
        isDebugging: Bool,
        onContinue: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onStepOver: @escaping () -> Void,
        onStepInto: @escaping () -> Void,
        onStepOut: @escaping () -> Void
    ) {
        self.isPaused = isPaused
        self.isDebugging = isDebugging
        self.onContinue = onContinue
        self.onPause = onPause
        self.onStepOver = onStepOver
        self.onStepInto = onStepInto
        self.onStepOut = onStepOut
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Continue / Pause
            if isPaused {
                Button(action: onContinue) {
                    Label("Continue", systemImage: "play.fill")
                }
                .help("Continue (F5)")
            } else {
                Button(action: onPause) {
                    Label("Pause", systemImage: "pause.fill")
                }
                .disabled(!isDebugging)
                .help("Pause")
            }

            Divider()
                .frame(height: 20)

            // Step controls
            Button(action: onStepOver) {
                Label("Step Over", systemImage: "arrow.right")
            }
            .disabled(!isPaused)
            .help("Step Over (F6)")

            Button(action: onStepInto) {
                Label("Step Into", systemImage: "arrow.down.right")
            }
            .disabled(!isPaused)
            .help("Step Into (F7)")

            Button(action: onStepOut) {
                Label("Step Out", systemImage: "arrow.up.left")
            }
            .disabled(!isPaused)
            .help("Step Out (F8)")
        }
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
    }
}
