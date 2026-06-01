import SwiftUI

struct ManageProjectsView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @State private var aliases: [UUID: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if projectStore.projects.isEmpty {
                Text("No projects added yet.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(Array(projectStore.projects.enumerated()), id: \.element.id) { index, project in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            if projectStore.activeProject?.id == project.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .frame(width: 16)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 16)
                            }
                            TextField("Alias", text: Binding(
                                get: { aliases[project.id] ?? project.name },
                                set: { aliases[project.id] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        Text(project.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .padding(.leading, 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if index < projectStore.projects.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }

            Divider()

            HStack {
                Button("Add Project…") {
                    chooseProject()
                }
                Spacer()
                Button("Save") {
                    for (id, name) in aliases {
                        projectStore.renameProject(id: id, name: name)
                    }
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding(12)
        }
        .frame(width: 420)
        .onAppear {
            aliases = Dictionary(uniqueKeysWithValues: projectStore.projects.map { ($0.id, $0.name) })
        }
    }

    private func chooseProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select SAP Commerce project root"
        panel.prompt = "Add Project"
        if panel.runModal() == .OK, let url = panel.url {
            projectStore.addProject(name: url.lastPathComponent, path: url.path)
            aliases[projectStore.projects.last!.id] = url.lastPathComponent
        }
    }
}
