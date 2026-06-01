import SwiftUI

struct IndexStatsView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var indexService: IndexService

    var body: some View {
        if let project = projectStore.activeProject {
            if let stats = indexService.stats {
                Text("Last indexed: \(stats.lastIndexedFormatted)")
                    .foregroundStyle(.secondary)
                Text("Classes: \(stats.classCountFormatted)")
                    .foregroundStyle(.secondary)
            } else if project.dbExists {
                Text("Index exists (loading…)")
                    .foregroundStyle(.secondary)
            } else {
                Text("Not indexed yet")
                    .foregroundStyle(.secondary)
            }

            if let error = indexService.rebuildError {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if indexService.isRebuilding {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Rebuilding…")
                }
            } else {
                Button("Rebuild Index") {
                    guard let proj = projectStore.activeProject else { return }
                    indexService.rebuild(
                        project: proj,
                        rubyPath: projectStore.rubyPath,
                        serverBinPath: projectStore.serverBinPath
                    )
                }
            }
        } else {
            Text("No project selected")
                .foregroundStyle(.secondary)
        }
    }
}
