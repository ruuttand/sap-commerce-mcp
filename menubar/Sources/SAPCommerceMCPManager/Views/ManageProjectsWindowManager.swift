import AppKit
import SwiftUI

class ManageProjectsWindowManager {
    static let shared = ManageProjectsWindowManager()
    private var window: NSWindow?

    func show(projectStore: ProjectStore) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = ManageProjectsView().environmentObject(projectStore)
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = .preferredContentSize

        let panel = NSPanel(contentViewController: hosting)
        panel.title = "Manage Projects"
        panel.styleMask = [.titled, .closable]
        panel.isReleasedWhenClosed = false
        panel.center()

        window = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
