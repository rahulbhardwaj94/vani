import AppKit
import CoreGraphics
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Tap once to start recording, tap again to stop (default ⌥⌘D).
    static let toggleDictation = Self("toggleDictation", default: .init(.d, modifiers: [.option, .command]))
}

/// Two activation styles:
///  - Toggle chord via KeyboardShortcuts (Carbon hotkey, user-customizable).
///  - Push-to-talk: hold Right Option, watched with a listen-only CGEventTap
///    on flagsChanged (Carbon hotkeys can't observe bare modifiers).
@MainActor
final class HotkeyManager {
    nonisolated static let rightOptionKeyCode: Int64 = 61

    var onPushToTalkDown: (() -> Void)?
    var onPushToTalkUp: (() -> Void)?
    var onToggle: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pttHeld = false

    func start() {
        KeyboardShortcuts.onKeyUp(for: .toggleDictation) { [weak self] in
            self?.onToggle?()
        }
        startEventTap()
    }

    // MARK: - Push-to-talk event tap

    private func startEventTap() {
        guard eventTap == nil else { return }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                manager.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            NSLog("rbFlow: could not create event tap (Input Monitoring not granted?)")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private nonisolated func handle(type: CGEventType, event: CGEvent) {
        // The system disables taps that stall or when the machine sleeps.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Task { @MainActor [weak self] in
                if let tap = self?.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return
        }
        guard type == .flagsChanged,
              event.getIntegerValueField(.keyboardEventKeycode) == Self.rightOptionKeyCode
        else { return }

        let isDown = event.flags.contains(.maskAlternate)
        Task { @MainActor [weak self] in
            guard let self, self.pttHeld != isDown else { return }
            self.pttHeld = isDown
            isDown ? self.onPushToTalkDown?() : self.onPushToTalkUp?()
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
