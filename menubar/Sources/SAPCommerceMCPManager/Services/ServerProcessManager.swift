import Foundation

@MainActor
class ServerProcessManager: ObservableObject {
    @Published var state: ServerState = .stopped
    @Published var launchError: String?

    private var process: Process?
    private var stdinPipe: Pipe?

    func start(project: Project, rubyPath: String, serverBinPath: String) {
        guard !state.isRunning else { return }
        state = .starting
        launchError = nil

        let p = Process()
        p.executableURL = URL(fileURLWithPath: rubyPath)
        p.arguments = [serverBinPath, project.path]

        let serverDir = URL(fileURLWithPath: serverBinPath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        var env = ProcessInfo.processInfo.environment
        env["BUNDLE_GEMFILE"] = "\(serverDir)/Gemfile"
        p.environment = env

        // Keep stdin open so the server doesn't exit immediately
        let stdin = Pipe()
        p.standardInput = stdin
        p.standardOutput = Pipe()  // discard MCP output — we're not the MCP client here
        p.standardError = Pipe()

        p.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                self?.state = .stopped
                self?.process = nil
                self?.stdinPipe = nil
            }
        }

        do {
            try p.run()
            process = p
            stdinPipe = stdin
            state = .running(pid: p.processIdentifier)
        } catch {
            launchError = error.localizedDescription
            state = .stopped
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        stdinPipe = nil
        state = .stopped
    }
}
