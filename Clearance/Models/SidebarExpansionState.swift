import Foundation

final class SidebarExpansionState: ObservableObject {
    @Published private(set) var expandedPaths: Set<String>

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(userDefaults: UserDefaults = .standard, storageKey: String = "sidebarExpandedPaths") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey

        if let stored = userDefaults.stringArray(forKey: storageKey) {
            expandedPaths = Set(stored)
        } else {
            expandedPaths = []
        }
    }

    func isExpanded(_ path: String) -> Bool {
        expandedPaths.contains(path)
    }

    func setExpanded(_ path: String, expanded: Bool) {
        if expanded {
            expandedPaths.insert(path)
        } else {
            expandedPaths.remove(path)
        }

        persist()
    }

    func toggle(_ path: String) {
        if expandedPaths.contains(path) {
            expandedPaths.remove(path)
        } else {
            expandedPaths.insert(path)
        }

        persist()
    }

    func expandIfUnknown(_ path: String) {
        guard !expandedPaths.contains(path) else {
            return
        }

        let knownKey = storageKey + ".known"
        var knownPaths = Set(userDefaults.stringArray(forKey: knownKey) ?? [])

        guard !knownPaths.contains(path) else {
            return
        }

        knownPaths.insert(path)
        userDefaults.set(Array(knownPaths), forKey: knownKey)

        expandedPaths.insert(path)
        persist()
    }

    private func persist() {
        userDefaults.set(Array(expandedPaths), forKey: storageKey)
    }
}
