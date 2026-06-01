import Foundation

enum ServerState: Equatable {
    case stopped
    case starting
    case running(pid: Int32)

    var label: String {
        switch self {
        case .stopped:       return "Stopped"
        case .starting:      return "Starting…"
        case .running(let pid): return "Running (PID \(pid))"
        }
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}
