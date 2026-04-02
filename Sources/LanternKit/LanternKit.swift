// LanternKit — Reusable UI components for Lantern development tools.
//
// Provides editor, console, preview, debug panels, and debug canvas views.
// Every view is independently usable — consumers can embed any subset.
//
// Note: We intentionally do NOT @_exported import Lantern here because
// Lantern re-exports LanternVM which defines an `Environment` class that
// collides with SwiftUI.Environment. Consumers should import Lantern
// explicitly if they need direct access to interpreter types.
