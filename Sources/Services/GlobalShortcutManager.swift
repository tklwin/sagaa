import Foundation
import Carbon.HIToolbox

public final class GlobalShortcutManager {
    public static let shared = GlobalShortcutManager()

    public var onTrigger: (() -> Void)?
    public var onKeyDown: (() -> Void)?
    public var onKeyUp: ((TimeInterval) -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var keyDownTimestamp: TimeInterval?

    private init() {}

    /// Registers system-wide shortcut: Control + Option + S (⌃⌥S)
    /// Supports both KeyDown and KeyUp for Push-to-Talk and Toggle modes
    public func registerDefaultShortcut() {
        unregisterShortcut()

        var eventTypes: [EventTypeSpec] = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let statusHandler = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData -> OSStatus in
                guard let userData = userData, let event = event else { return OSStatus(eventNotHandledErr) }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

                // Check signature 'SGAA' (0x53474141)
                if hotKeyID.signature == 0x5347_4141 && hotKeyID.id == 1 {
                    let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                    let eventKind = Int(GetEventKind(event))

                    DispatchQueue.main.async {
                        if eventKind == kEventHotKeyPressed {
                            manager.handleKeyDown()
                        } else if eventKind == kEventHotKeyReleased {
                            manager.handleKeyUp()
                        }
                    }
                    return noErr
                }
                return OSStatus(eventNotHandledErr)
            },
            2,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard statusHandler == noErr else {
            print("⚠️ Failed to install Carbon event handler for shortcut")
            return
        }

        // kVK_ANSI_S = 0x01
        let kVK_ANSI_S: UInt32 = 0x01
        let carbonModifiers = UInt32(controlKey | optionKey)
        let hotKeyID = EventHotKeyID(signature: 0x5347_4141, id: 1)

        var ref: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(
            kVK_ANSI_S,
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )

        if regStatus == noErr, let ref = ref {
            self.hotKeyRef = ref
            print("✅ Global shortcut ⌃⌥S registered successfully via Carbon (KeyDown + KeyUp)")
        } else {
            print("⚠️ Failed to register hotkey: \(regStatus)")
        }
    }

    private func handleKeyDown() {
        keyDownTimestamp = ProcessInfo.processInfo.systemUptime
        onKeyDown?()
        onTrigger?()
    }

    private func handleKeyUp() {
        guard let start = keyDownTimestamp else { return }
        let duration = ProcessInfo.processInfo.systemUptime - start
        keyDownTimestamp = nil
        onKeyUp?(duration)
    }

    public func unregisterShortcut() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregisterShortcut()
    }
}
