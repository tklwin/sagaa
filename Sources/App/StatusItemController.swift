import AppKit

public final class StatusItemController {
    public var onLeftClick: (() -> Void)?
    public var onRightClick: ((NSStatusBarButton?) -> Void)?

    private(set) var statusItem: NSStatusItem!
    private var idleIcon: NSImage?
    private var recordingIcon: NSImage?
    private var transcribingIcon: NSImage?

    public var button: NSStatusBarButton? {
        statusItem?.button
    }

    public init() {
        setupIcons()
        installStatusItem()
    }

    private func setupIcons() {
        if let idle = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Sagaa") {
            idle.isTemplate = true
            self.idleIcon = idle
        }
        if let rec = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording") {
            rec.isTemplate = true
            self.recordingIcon = rec
        }
        if let trans = NSImage(systemSymbolName: "waveform.badge.magnifyingglass", accessibilityDescription: "Transcribing") {
            trans.isTemplate = true
            self.transcribingIcon = trans
        }
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "SagaaMenuBarItem"
        statusItem.behavior = []
        statusItem.isVisible = true

        if let button = statusItem.button {
            button.image = idleIcon
            button.imagePosition = .imageLeading
            button.title = " Sagaa"
            button.toolTip = "Sagaa - Offline Burmese Speech-to-Text\nLeft-click: Open Panel\nRight-click: Quick Menu\nShortcut: Control+Option+S"
            button.target = self
            button.action = #selector(statusBarButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusBarButtonClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            onRightClick?(statusItem.button)
        } else {
            onLeftClick?()
        }
    }

    public func setRecordingState() {
        guard let button = statusItem.button else { return }
        button.image = recordingIcon
        button.title = " Recording..."
    }

    public func setTranscribingState() {
        guard let button = statusItem.button else { return }
        button.image = transcribingIcon
        button.title = " Transcribing..."
    }

    public func setIdleState() {
        guard let button = statusItem.button else { return }
        button.image = idleIcon
        button.title = " Sagaa"
    }
}
