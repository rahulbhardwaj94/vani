/// Central kill-switches for features under evaluation. Flip one line and
/// rebuild — the settings UI, gestures, and model loading all follow.
enum FeatureFlags {
    /// Live partial transcript in the HUD while speaking. OFF (2026-07):
    /// whisper-small hallucinates words from ambient noise and preview
    /// passes lag behind speech on real hardware. Also gates the preview
    /// model's warm-up, so disabling saves ~0.5 GB of memory.
    static let streamingPreview = false

    /// Holding the PTT key ≥1.5 s and releasing locks hands-free. OFF:
    /// double-tap is the deliberate way in; the hold fallback caused
    /// accidental locks when people paused mid-thought while holding.
    static let holdToLockHandsFree = false
}
