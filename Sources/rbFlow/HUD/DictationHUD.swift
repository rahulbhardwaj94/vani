import AppKit
import SwiftUI

/// Floating pill shown near the bottom of the screen during dictation:
/// level-reactive bars while recording, animated dots while processing.
/// It never takes focus (non-activating panel) so the target app keeps
/// its text field focused for the paste.
@MainActor
final class DictationHUD {
    static let shared = DictationHUD()

    private var panel: NSPanel?

    func show() {
        if panel == nil {
            let hosting = NSHostingView(rootView: HUDView())
            let size = NSSize(width: 180, height: 44)
            let p = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: true
            )
            p.contentView = hosting
            p.isOpaque = false
            p.backgroundColor = .clear
            p.level = .statusBar
            p.hasShadow = true
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            p.isReleasedWhenClosed = false
            panel = p
        }
        position()
        panel?.alphaValue = 0
        panel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel?.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in panel.orderOut(nil) }
        })
    }

    private func position() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.minY + 80
        )
        panel.setFrameOrigin(origin)
    }
}

private struct HUDView: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        HStack(spacing: 10) {
            switch appState.status {
            case .recording:
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
                LevelBars(level: appState.audioLevel)
            case .transcribing, .injecting:
                ProcessingDots()
                Text(appState.status == .transcribing ? "Transcribing…" : "Inserting…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .idle:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .frame(width: 180, height: 44)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary))
    }
}

/// Audio-level-reactive bars. Each bar scales with the mic level plus a
/// per-bar phase wobble so the pill feels alive even at steady volume.
private struct LevelBars: View {
    let level: Float
    private let barCount = 10

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    let wobble = 0.6 + 0.4 * sin(time * 9 + Double(i) * 1.1)
                    let height = 4 + CGFloat(min(level * 14, 1)) * 22 * wobble
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.tint)
                        .frame(width: 3, height: max(4, height))
                }
            }
        }
        .frame(height: 26)
    }
}

private struct ProcessingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.tint)
                        .frame(width: 6, height: 6)
                        .opacity(0.35 + 0.65 * (0.5 + 0.5 * sin(time * 6 - Double(i) * 0.9)))
                }
            }
        }
    }
}
