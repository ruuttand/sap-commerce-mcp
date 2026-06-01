import SwiftUI

struct ServerControlView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var serverManager: ServerProcessManager

    var body: some View {
        Text("MCP Server: \(serverManager.state.label)")
            .foregroundStyle(.secondary)

        if let error = serverManager.launchError {
            Text("Error: \(error)")
                .foregroundStyle(.red)
                .lineLimit(2)
        }

        if serverManager.state.isRunning {
            Button("Stop Server") {
                serverManager.stop()
            }
        } else if case .starting = serverManager.state {
            Text("Starting…")
                .foregroundStyle(.secondary)
        } else {
            Button("Start Server") {
                guard let project = projectStore.activeProject else { return }
                serverManager.start(
                    project: project,
                    rubyPath: projectStore.rubyPath,
                    serverBinPath: projectStore.serverBinPath
                )
            }
            .disabled(projectStore.activeProject == nil)
        }
    }
}
