import SwiftUI

@main
struct SAPCommerceMCPManagerApp: App {
    @StateObject private var projectStore = ProjectStore()
    @StateObject private var indexService = IndexService()
    @StateObject private var serverManager = ServerProcessManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(projectStore)
                .environmentObject(indexService)
                .environmentObject(serverManager)
                .onAppear {
                    if let project = projectStore.activeProject {
                        indexService.refresh(for: project)
                    }
                }
        } label: {
            MenuBarStatusLabel(indexService: indexService, serverManager: serverManager)
        }
        .menuBarExtraStyle(.window)

    }
}
