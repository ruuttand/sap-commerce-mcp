import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @State private var rubyPath: String = ""
    @State private var serverBinPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ruby path:")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Ruby binary path", text: $rubyPath)
                .font(.caption)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            Text("Server binary path:")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("sap-commerce-mcp path", text: $serverBinPath)
                .font(.caption)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            HStack {
                Spacer()
                Button("Save") {
                    projectStore.updateSettings(rubyPath: rubyPath, serverBinPath: serverBinPath)
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .onAppear {
            rubyPath = projectStore.rubyPath
            serverBinPath = projectStore.serverBinPath
        }
    }
}
