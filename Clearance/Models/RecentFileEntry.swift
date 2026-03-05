import Foundation

struct RecentFileEntry: Codable, Equatable, Identifiable {
    let path: String
    let lastOpenedAt: Date

    var id: String { path }

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var directoryPath: String {
        fileURL.deletingLastPathComponent().path
    }

    var fileURL: URL {
        URL(fileURLWithPath: path)
    }

    init(path: String, lastOpenedAt: Date = .now) {
        self.path = path
        self.lastOpenedAt = lastOpenedAt
    }

    enum CodingKeys: String, CodingKey {
        case path
        case lastOpenedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt) ?? .distantPast
    }
}
