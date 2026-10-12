import Foundation
import Carbon.HIToolbox

public final class GlobalShortcutManager {
    public static let shared = GlobalShortcutManager()

    public var onTrigger: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {}

    /// Registers system-wide shortcut: Control + Option + S (⌃⌥S)
    public func registerDefaultShortcut() {
        unregisterShortcut()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        let statusHandler = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                if let event = event {
                    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                      EventParamType(typeEventHotKeyID), nil,
                                      MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                }

                // Check signature 'SGAA' (0x53474141)
                if hotKeyID.signature == 0x5347_4141 && hotKeyID.id == 1 {
                    let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                    DispatchQueue.main.async {
                        manager.onTrigger?()
                    }
                    return noErr
                }
                return OSStatus(eventNotHandledErr)
            },
            1,
            &eventType,
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
            print("✅ Global shortcut ⌃⌥S registered successfully via Carbon")
        } else {
            print("⚠️ Failed to register hotkey: \(regStatus)")
        }
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
