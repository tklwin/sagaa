import AppKit
import SwiftUI

public final class SettingsWindowController: NSWindowController {
    public static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sagaa Settings"
        window.center()
        window.setFrameAutosaveName("SagaaSettingsWindow")
        window.isReleasedWhenClosed = false

        let contentView = SettingsView(state: AppState.shared)
        window.contentViewController = NSHostingController(rootView: contentView)

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showSettings() {
        AppState.shared.refreshPermissions()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

