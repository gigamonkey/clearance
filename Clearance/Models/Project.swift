import Foundation

struct Project: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var directoryPaths: [String]

    init(id: UUID = UUID(), name: String, directoryPaths: [String] = []) {
        self.id = id
        self.name = name
        self.directoryPaths = directoryPaths
    }
}
