import Foundation

struct Commit: Identifiable, Hashable {
    let id: String // hash
    let message: String
    let author: String
    let date: Date
    var linesAdded: Int
    var linesRemoved: Int

    var shortHash: String {
        String(id.prefix(7))
    }

    var shortMessage: String {
        let firstLine = message.components(separatedBy: .newlines).first ?? message
        if firstLine.count > 50 {
            return String(firstLine.prefix(47)) + "..."
        }
        return firstLine
    }

    var netLines: Int {
        linesAdded - linesRemoved
    }

    init(id: String, message: String, author: String, date: Date, linesAdded: Int = 0, linesRemoved: Int = 0) {
        self.id = id
        self.message = message
        self.author = author
        self.date = date
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
    }

    static func fromGitLog(_ line: String) -> Commit? {
        let parts = line.components(separatedBy: "|")
        guard parts.count >= 4 else { return nil }

        let hash = parts[0]
        let message = parts[1]
        let author = parts[2]
        let dateString = parts[3]

        guard let date = Date.fromGitDate(dateString) else { return nil }

        return Commit(id: hash, message: message, author: author, date: date)
    }
}
