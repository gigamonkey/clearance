import CoreServices
import Foundation

@MainActor
final class DirectoryMonitor: ObservableObject {
    @Published private(set) var treesByDirectory: [String: ProjectFileNode] = [:]

    private var monitoredPaths: Set<String> = []
    private var eventStream: FSEventStreamRef?
    private let supportedExtensions: Set<String> = ["md", "markdown", "txt"]

    func updateMonitoredDirectories(_ paths: Set<String>) {
        guard paths != monitoredPaths else {
            return
        }

        stopStream()
        monitoredPaths = paths

        var newTrees: [String: ProjectFileNode] = [:]
        for path in paths {
            if let existing = treesByDirectory[path] {
                newTrees[path] = existing
            }
        }
        treesByDirectory = newTrees

        guard !paths.isEmpty else {
            return
        }

        enumerateAllDirectories()
        startStream()
    }

    func stopAll() {
        stopStream()
        monitoredPaths.removeAll()
        treesByDirectory.removeAll()
    }

    private static let backgroundQueue = DispatchQueue(
        label: "com.jesse.Clearance.DirectoryMonitor",
        qos: .userInitiated
    )

    private func enumerateAllDirectories() {
        let paths = monitoredPaths
        let extensions = supportedExtensions

        Self.backgroundQueue.async { [weak self] in
            var results: [String: ProjectFileNode] = [:]
            for path in paths {
                results[path] = DirectoryMonitor.enumerateDirectory(path, supportedExtensions: extensions)
            }

            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                for (path, tree) in results {
                    if self.monitoredPaths.contains(path) {
                        self.treesByDirectory[path] = tree
                    }
                }
            }
        }
    }

    fileprivate func reenumerateAffectedPaths(_ changedPaths: [String]) {
        let roots = monitoredPaths
        let extensions = supportedExtensions

        var affectedRoots: Set<String> = []
        for changedPath in changedPaths {
            for root in roots where changedPath.hasPrefix(root) {
                affectedRoots.insert(root)
            }
        }

        guard !affectedRoots.isEmpty else {
            return
        }

        Self.backgroundQueue.async { [weak self] in
            var results: [String: ProjectFileNode] = [:]
            for root in affectedRoots {
                results[root] = DirectoryMonitor.enumerateDirectory(root, supportedExtensions: extensions)
            }

            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                for (path, tree) in results {
                    if self.monitoredPaths.contains(path) {
                        self.treesByDirectory[path] = tree
                    }
                }
            }
        }
    }

    nonisolated private static func enumerateDirectory(
        _ directoryPath: String,
        supportedExtensions: Set<String>
    ) -> ProjectFileNode {
        let rootURL = URL(fileURLWithPath: directoryPath)
        var filesByDirectory: [String: [ProjectFileNode]] = [:]

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return ProjectFileNode(
                path: directoryPath,
                name: rootURL.lastPathComponent,
                isDirectory: true,
                children: []
            )
        }

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) else {
                continue
            }

            if values.isDirectory == true {
                continue
            }

            guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
                continue
            }

            let parentPath = url.deletingLastPathComponent().path
            let fileNode = ProjectFileNode(
                path: url.path,
                name: url.lastPathComponent,
                isDirectory: false,
                children: []
            )
            filesByDirectory[parentPath, default: []].append(fileNode)
        }

        return buildTree(
            rootPath: directoryPath,
            rootName: rootURL.lastPathComponent,
            filesByDirectory: filesByDirectory
        )
    }

    nonisolated private static func buildTree(
        rootPath: String,
        rootName: String,
        filesByDirectory: [String: [ProjectFileNode]]
    ) -> ProjectFileNode {
        var allDirectoryPaths: Set<String> = []
        for dirPath in filesByDirectory.keys {
            var current = dirPath
            while current.hasPrefix(rootPath) && current != rootPath {
                allDirectoryPaths.insert(current)
                current = (current as NSString).deletingLastPathComponent
            }
        }

        let sortedDirectoryPaths = allDirectoryPaths.sorted { $0 > $1 }

        var directoryNodes: [String: ProjectFileNode] = [:]

        for dirPath in sortedDirectoryPaths {
            let name = (dirPath as NSString).lastPathComponent
            var children: [ProjectFileNode] = []

            if let files = filesByDirectory[dirPath] {
                children.append(contentsOf: files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
            }

            let childDirPaths = allDirectoryPaths.filter {
                ($0 as NSString).deletingLastPathComponent == dirPath
            }.sorted()

            for childDirPath in childDirPaths {
                if let childNode = directoryNodes[childDirPath] {
                    children.append(childNode)
                    directoryNodes.removeValue(forKey: childDirPath)
                }
            }

            directoryNodes[dirPath] = ProjectFileNode(
                path: dirPath,
                name: name,
                isDirectory: true,
                children: children
            )
        }

        var rootChildren: [ProjectFileNode] = []

        if let rootFiles = filesByDirectory[rootPath] {
            rootChildren.append(contentsOf: rootFiles.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            })
        }

        let topLevelDirPaths = directoryNodes.keys.filter {
            ($0 as NSString).deletingLastPathComponent == rootPath
        }.sorted()

        for dirPath in topLevelDirPaths {
            if let node = directoryNodes[dirPath] {
                rootChildren.append(node)
            }
        }

        return ProjectFileNode(
            path: rootPath,
            name: rootName,
            isDirectory: true,
            children: rootChildren
        )
    }

    private func startStream() {
        guard !monitoredPaths.isEmpty else {
            return
        }

        let pathsArray = Array(monitoredPaths) as CFArray
        let contextPtr = Unmanaged.passUnretained(self).toOpaque()

        var context = FSEventStreamContext(
            version: 0,
            info: contextPtr,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            pathsArray as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else {
            return
        }

        eventStream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    private func stopStream() {
        guard let stream = eventStream else {
            return
        }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }
}

private func fsEventsCallback(
    _ streamRef: ConstFSEventStreamRef,
    _ clientCallBackInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let clientCallBackInfo else {
        return
    }

    let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()

    guard let cfPaths = unsafeBitCast(eventPaths, to: CFArray?.self) else {
        return
    }

    var changedPaths: [String] = []
    for i in 0..<numEvents {
        if let path = unsafeBitCast(CFArrayGetValueAtIndex(cfPaths, i), to: CFString?.self) as String? {
            changedPaths.append(path)
        }
    }

    Task { @MainActor in
        monitor.reenumerateAffectedPaths(changedPaths)
    }
}
