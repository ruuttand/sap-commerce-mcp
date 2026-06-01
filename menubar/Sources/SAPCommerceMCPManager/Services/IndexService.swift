import Foundation
import SQLite3

@MainActor
class IndexService: ObservableObject {
    @Published var stats: IndexStats?
    @Published var isRebuilding = false
    @Published var rebuildError: String?

    func refresh(for project: Project) {
        stats = readStats(dbPath: project.dbPath)
    }

    func rebuild(project: Project, rubyPath: String, serverBinPath: String) {
        guard !isRebuilding else { return }
        isRebuilding = true
        rebuildError = nil

        Task.detached { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: rubyPath)
            process.arguments = [serverBinPath, "--rebuild-only", project.path]

            // BUNDLE_GEMFILE so bundler finds gems regardless of working directory
            let serverDir = URL(fileURLWithPath: serverBinPath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path
            var env = ProcessInfo.processInfo.environment
            env["BUNDLE_GEMFILE"] = "\(serverDir)/Gemfile"
            env["SAP_MCP_USE_REGEX_PARSER"] = nil
            process.environment = env

            let stderr = Pipe()
            process.standardError = stderr

            do {
                try process.run()
                process.waitUntilExit()
                let exitCode = process.terminationStatus
                let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                await MainActor.run { [weak self] in
                    if exitCode == 0 {
                        self?.rebuildError = nil
                        self?.refresh(for: project)
                    } else {
                        self?.rebuildError = errorOutput.isEmpty ? "Rebuild failed (exit \(exitCode))" : errorOutput
                    }
                    self?.isRebuilding = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.rebuildError = error.localizedDescription
                    self?.isRebuilding = false
                }
            }
        }
    }

    private func readStats(dbPath: String) -> IndexStats? {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }

        let lastIndexed = queryScalarString(db: db, sql: "SELECT value FROM index_metadata WHERE key = 'last_indexed'")
            .flatMap { TimeInterval($0) }
            .map { Date(timeIntervalSince1970: $0) }

        let classCount = queryScalarInt(db: db, sql: "SELECT COUNT(*) FROM classes") ?? 0

        return IndexStats(lastIndexed: lastIndexed, classCount: classCount)
    }

    private func queryScalarString(db: OpaquePointer?, sql: String) -> String? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        guard let cStr = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: cStr)
    }

    private func queryScalarInt(db: OpaquePointer?, sql: String) -> Int? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Int(sqlite3_column_int64(stmt, 0))
    }
}
