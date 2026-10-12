import AppKit
import SwiftUI

public final class SagaaHUDPanel: NSPanel {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
    public override func accessibilitySubrole() -> NSAccessibility.Subrole? { .unknown }
}

public final class SagaaHUDController: NSWindowController {
    public static let shared = SagaaHUDController()

    private var hideWorkItem: DispatchWorkItem?

    private init() {
        let panel = SagaaHUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.alphaValue = 0.0

        let hosting = NSHostingController(rootView: SagaaHUDView(state: AppState.shared))
        panel.contentViewController = hosting

        super.init(window: panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Positions and presents the floating HUD pill
    public func show() {
        guard AppState.shared.showFloatingHUD else { return }
        hideWorkItem?.cancel()

        guard let window = self.window else { return }

        // Position at bottom center of the active display
        let screen = NSScreen.main ?? NSScreen.screens.first
        if let screenFrame = screen?.visibleFrame {
            let width: CGFloat = 260
            let height: CGFloat = 50
            let x = screenFrame.midX - (width / 2.0)
            let y = screenFrame.minY + 40 // 40pt above Dock or screen bottom
            window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }

        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }
    }

    /// Dismisses the HUD smoothly
    public func hide(afterDelay: TimeInterval = 0.0) {
        hideWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let window = self?.window else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 0.0
            }, completionHandler: {
                if window.alphaValue == 0.0 {
                    window.orderOut(nil)
                }
            })
        }

        hideWorkItem = work
        if afterDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + afterDelay, execute: work)
        } else {
            work.perform()
        }
    }
}
