import AppKit
import SwiftUI

class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?

    func show(projectStore: ProjectStore) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView().environmentObject(projectStore)
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = .preferredContentSize

        let panel = NSPanel(contentViewController: hosting)
        panel.title = "SAP Commerce MCP — Settings"
        panel.styleMask = [.titled, .closable]
        panel.isReleasedWhenClosed = false
        panel.center()

        window = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
