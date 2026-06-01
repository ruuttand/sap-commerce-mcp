import SwiftUI
import ServiceManagement
import AppKit

private struct TransparentWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.backgroundColor = .clear
            window.isOpaque = false
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct MenuBarView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var indexService: IndexService
    @EnvironmentObject var serverManager: ServerProcessManager
    @State private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
        // Active project header
        if let project = projectStore.activeProject {
            Text(project.displayName)
                .fontWeight(.semibold)
            Text(project.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
            Text("Index: \(MD5Helper.dbHash(project.path)).db")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            Text("No project selected")
                .foregroundStyle(.secondary)
        }

        Divider()

        // Projects submenu
        Menu("Projects") {
            ProjectPickerView()
        }

        Divider()

        // Index section
        IndexStatsView()

        Divider()

        // Server section
        ServerControlView()

        Divider()

        Button("Open Logs in Finder") {
            let path = ("~/.sap-commerce-mcp/logs" as NSString).expandingTildeInPath
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }

        Button("Open Indexes in Finder") {
            let path = ("~/.sap-commerce-mcp/indexes" as NSString).expandingTildeInPath
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }

        Divider()

        Button("Settings…") {
            SettingsWindowManager.shared.show(projectStore: projectStore)
        }

        Toggle("Launch at Login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { enabled in
                toggleLaunchAtLogin(enabled)
            }
            .onAppear {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }

        Divider()

        Button("Quit") {
            serverManager.stop()
            NSApplication.shared.terminate(nil)
        }
        } // VStack
        .frame(minWidth: 280)
        .padding(10)
        .background(.ultraThinMaterial)
        .background(TransparentWindow())
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently ignore — SMAppService can fail on unsigned apps
        }
    }
}
