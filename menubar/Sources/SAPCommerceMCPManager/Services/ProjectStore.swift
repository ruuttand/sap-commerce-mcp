import Foundation

private struct AppConfig: Codable {
    var projects: [Project]
    var activeProjectId: UUID?
    var rubyPath: String
    var serverBinPath: String
}

@MainActor
class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var activeProject: Project?
    @Published var rubyPath: String = ""
    @Published var serverBinPath: String = ""

    private let configPath = ("~/.sap-commerce-mcp/app-config.json" as NSString).expandingTildeInPath
    private let activeProjectFile = ("~/.sap-commerce-mcp/active-project" as NSString).expandingTildeInPath

    init() {
        loadFromDisk()
    }

    func addProject(name: String, path: String) {
        let project = Project(name: name, path: path)
        projects.append(project)
        if activeProject == nil {
            setActive(project)
        }
        saveToDisk()
    }

    func renameProject(id: UUID, name: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = name
        if activeProject?.id == id { activeProject = projects[index] }
        saveToDisk()
    }

    func removeProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        if activeProject?.id == project.id {
            activeProject = projects.first
            writeActiveProjectFile()
        }
        saveToDisk()
    }

    func setActive(_ project: Project) {
        activeProject = project
        writeActiveProjectFile()
        saveToDisk()
    }

    func updateSettings(rubyPath: String, serverBinPath: String) {
        self.rubyPath = rubyPath
        self.serverBinPath = serverBinPath
        saveToDisk()
    }

    private func writeActiveProjectFile() {
        let content = activeProject?.path ?? ""
        try? content.write(toFile: activeProjectFile, atomically: true, encoding: .utf8)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            // Defaults — detect existing projects from start.sh scripts
            rubyPath = defaultRubyPath()
            serverBinPath = defaultServerBinPath()
            return
        }
        projects = config.projects
        rubyPath = config.rubyPath
        serverBinPath = config.serverBinPath
        if let id = config.activeProjectId {
            activeProject = projects.first { $0.id == id }
        }
    }

    private func saveToDisk() {
        ensureConfigDir()
        let config = AppConfig(
            projects: projects,
            activeProjectId: activeProject?.id,
            rubyPath: rubyPath,
            serverBinPath: serverBinPath
        )
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: URL(fileURLWithPath: configPath))
    }

    private func ensureConfigDir() {
        let dir = ("~/.sap-commerce-mcp" as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    private func defaultRubyPath() -> String {
        // Look for rbenv ruby first, then fall back to /usr/bin/ruby
        let rbenvPath = (("~/.rbenv/shims/ruby") as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: rbenvPath) {
            // Prefer the actual binary over the shim to avoid PATH issues
            if let versionsDir = try? FileManager.default.contentsOfDirectory(
                atPath: ("~/.rbenv/versions" as NSString).expandingTildeInPath
            ).sorted().last {
                let candidate = ("~/.rbenv/versions/\(versionsDir)/bin/ruby" as NSString).expandingTildeInPath
                if FileManager.default.fileExists(atPath: candidate) { return candidate }
            }
            return rbenvPath
        }
        return "/usr/bin/ruby"
    }

    private func defaultServerBinPath() -> String {
        let candidates = [
            // Common dev location — git repo next to the app
            ("~/git/sap-commerce-mcp/bin/sap-commerce-mcp" as NSString).expandingTildeInPath,
            // Sibling of the app bundle (e.g. deployed together)
            Bundle.main.bundleURL.deletingLastPathComponent()
                .appendingPathComponent("bin/sap-commerce-mcp").path,
            // Homebrew-style install
            "/usr/local/bin/sap-commerce-mcp",
            "/opt/homebrew/bin/sap-commerce-mcp",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
            ?? candidates[0]  // return the git path as a hint even if missing
    }
}
