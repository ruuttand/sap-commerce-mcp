import SwiftUI

struct ProjectPickerView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var indexService: IndexService
    @EnvironmentObject var serverManager: ServerProcessManager
    @State private var isShowingAddSheet = false
    @State private var newProjectName = ""
    @State private var newProjectPath = ""

    var body: some View {
        ForEach(projectStore.projects) { project in
            Button {
                switchTo(project)
            } label: {
                HStack {
                    Text(project.displayName)
                    Spacer()
                    if projectStore.activeProject?.id == project.id {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .buttonStyle(.plain)
        }

        if !projectStore.projects.isEmpty {
            Divider()
        }

        Button("Manage Projects…") {
            ManageProjectsWindowManager.shared.show(projectStore: projectStore)
        }
    }

    private func switchTo(_ project: Project) {
        let wasRunning = serverManager.state.isRunning
        projectStore.setActive(project)
        indexService.refresh(for: project)
        guard wasRunning else { return }
        serverManager.stop()
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            serverManager.start(
                project: project,
                rubyPath: projectStore.rubyPath,
                serverBinPath: projectStore.serverBinPath
            )
        }
    }
}
