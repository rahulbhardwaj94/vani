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
            let size = NSSize(width: 230, height: 48)
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
                PulsingRing()
                FlowingWave(level: appState.audioLevel)
                Text("Listening")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))
            case .transcribing, .injecting:
                ProcessingDots()
                Text(appState.status == .transcribing ? "Transcribing…" : "Inserting…")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))
            case .inserted:
                InsertedBadge()
                Text("Inserted")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
            case .idle:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .frame(width: 230, height: 48)
        .background(AuroraGlass())
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .tint(.blue)
    }
}

/// "Aurora Glass": near-black frosted glass with faint violet/indigo auroras
/// drifting inside the pill. Premium, cinematic, and dark in any wallpaper.
private struct AuroraGlass: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(0.62)
                // Two slow-drifting aurora blooms.
                RadialGradient(
                    colors: [Color.purple.opacity(0.32), .clear],
                    center: UnitPoint(x: 0.25 + 0.1 * sin(time * 0.4), y: 0.1),
                    startRadius: 0, endRadius: 90
                )
                RadialGradient(
                    colors: [Color.indigo.opacity(0.28), .clear],
                    center: UnitPoint(x: 0.8 + 0.08 * sin(time * 0.3 + 2), y: 0.9),
                    startRadius: 0, endRadius: 100
                )
            }
        }
    }
}

/// Soft pulsing ring around a small core dot — the "live" indicator.
private struct PulsingRing: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            // 0→1 sawtooth every 1.6 s drives the expanding ring.
            let phase = (time / 1.6).truncatingRemainder(dividingBy: 1)
            ZStack {
                Circle()
                    .strokeBorder(Color.cyan.opacity(0.5 * (1 - phase)), lineWidth: 1.5)
                    .frame(width: 8 + 14 * phase, height: 8 + 14 * phase)
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .cyan],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 7, height: 7)
            }
            .frame(width: 22, height: 22)
        }
    }
}

/// Checkmark badge for the "Inserted" confirmation, ringed like the concept.
private struct InsertedBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                .frame(width: 22, height: 22)
            Circle()
                .fill(
                    LinearGradient(colors: [.indigo.opacity(0.9), .purple.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 18, height: 18)
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

/// Continuous voice-reactive waveform: three layered sine waves drifting at
/// different speeds, their amplitude driven by the mic level and tapered at
/// the edges so the wave melts into the pill.
private struct FlowingWave: View {
    let level: Float

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                let midY = size.height / 2
                // Slow breath so the wave feels alive even in silence.
                let breath = 0.9 + 0.1 * sin(time * 1.4)
                let amplitude = midY * (0.18 + min(CGFloat(level) * 12, 1) * 0.82) * breath

                let layers: [(speed: Double, freq: Double, scale: CGFloat, opacity: Double)] = [
                    (2.2, 1.4, 1.0, 1.0),
                    (-1.6, 2.1, 0.62, 0.55),
                    (2.9, 3.2, 0.34, 0.3),
                ]

                for layer in layers {
                    var path = Path()
                    let steps = 72
                    for i in 0...steps {
                        let x = CGFloat(i) / CGFloat(steps)
                        // Edge taper plus a slow traveling crest, so peaks
                        // roll across the pill instead of pulsing in place.
                        let taper = pow(sin(CGFloat.pi * x), 0.8)
                        let crest = 0.72 + 0.28 * sin(Double(x) * 2 * Double.pi * 0.8 - time * 1.7)
                        // Three slightly detuned harmonics per layer make the
                        // motion organic rather than metronomic.
                        let base = Double(x) * layer.freq * 2 * .pi
                        let wave = 0.6 * sin(base + time * layer.speed * 2)
                            + 0.28 * sin(base * 1.9 + time * layer.speed * 1.3 + 1.2)
                            + 0.12 * sin(base * 2.8 - time * layer.speed * 0.8 + 2.6)
                        let y = midY + amplitude * layer.scale * taper * CGFloat(crest) * CGFloat(wave)
                        let point = CGPoint(x: x * size.width, y: y)
                        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }

                    // Iridescent aurora sweep: violet → blue → cyan → violet.
                    let gradient = GraphicsContext.Shading.linearGradient(
                        Gradient(colors: [
                            .purple.opacity(layer.opacity * 0.8),
                            .blue.opacity(layer.opacity * 0.9),
                            .cyan.opacity(layer.opacity),
                            .purple.opacity(layer.opacity * 0.7),
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    )

                    // Soft halo just behind the filament — present, not neon.
                    let haloGradient = GraphicsContext.Shading.linearGradient(
                        Gradient(colors: [
                            .purple.opacity(layer.opacity * 0.25),
                            .cyan.opacity(layer.opacity * 0.35),
                            .purple.opacity(layer.opacity * 0.25),
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: 0)
                    )
                    var glow = canvas
                    glow.addFilter(.blur(radius: 2.5))
                    glow.stroke(
                        path,
                        with: haloGradient,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                    )
                    // Core filament.
                    canvas.stroke(
                        path,
                        with: gradient,
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .frame(width: 96, height: 32)
    }
}

private struct ProcessingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    let pulse = 0.5 + 0.5 * sin(time * 5 - Double(i) * 0.9)
                    Circle()
                        .fill(.cyan)
                        .frame(width: 6, height: 6)
                        .opacity(0.35 + 0.65 * pulse)
                        .shadow(color: .cyan.opacity(0.8 * pulse), radius: 4)
                        .scaleEffect(0.85 + 0.3 * pulse)
                }
            }
        }
    }
}
