import Foundation

struct IndexStats {
    let lastIndexed: Date?
    let classCount: Int

    var lastIndexedFormatted: String {
        guard let date = lastIndexed else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var classCountFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: classCount)) ?? "\(classCount)"
    }
}
