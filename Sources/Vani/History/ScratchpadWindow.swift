import SwiftUI
import AppKit

/// A dictation scratchpad: a plain editor you can speak into (it's a normal
/// focused text view, so the paste pipeline lands here like anywhere else)
/// and copy from whenever you like. Contents persist across launches.
struct ScratchpadView: View {
    @AppStorage("scratchpadText") private var text = ""
    @State private var copied = false

    private var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)

            Divider()
            HStack {
                Text("\(wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(copied ? "Copied ✓" : "Copy All") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                }
                .disabled(text.isEmpty)
                Button("Clear", role: .destructive) { text = "" }
                    .disabled(text.isEmpty)
            }
            .padding(10)
        }
        .frame(minWidth: 380, minHeight: 260)
    }
}

@MainActor
final class ScratchpadWindow {
    static let shared = ScratchpadWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: ScratchpadView())
            let win = NSWindow(contentViewController: hosting)
            win.title = "Vani Scratchpad"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.setContentSize(NSSize(width: 460, height: 320))
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
