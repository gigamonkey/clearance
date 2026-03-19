import AppKit
import SwiftUI

struct ProjectsSidebar: View {
    let projects: [Project]
    let treesByDirectory: [String: ProjectFileNode]
    @Binding var selectedPath: String?
    let onSelectFile: (ProjectFileNode) -> Void
    let onOpenInNewWindow: (ProjectFileNode) -> Void
    let onCreateProject: () -> UUID?
    let onRenameProject: (Project, String) -> Void
    let onDeleteProject: (Project) -> Void
    let onAddDirectory: (Project) -> Void
    let onRemoveDirectory: (Project, String) -> Void

    @State private var editingProjectID: UUID?
    @State private var editingName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.headline)

                Spacer()

                Button {
                    if let newID = onCreateProject() {
                        editingName = "New Project"
                        editingProjectID = newID
                    }
                } label: {
                    Label("New Project", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            if projects.isEmpty {
                ContentUnavailableView {
                    Label("No Projects", systemImage: "folder")
                } description: {
                    Text("Click + to create a project.")
                }
            } else {
                List(selection: $selectedPath) {
                    ForEach(projects) { project in
                        Section {
                            projectContent(for: project)
                        } header: {
                            projectHeader(for: project)
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selectedPath) { _, newPath in
                    guard let newPath else {
                        return
                    }

                    let fileNode = findFileNode(path: newPath)
                    if let fileNode, !fileNode.isDirectory {
                        onSelectFile(fileNode)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func projectHeader(for project: Project) -> some View {
        if editingProjectID == project.id {
            TextField("Project Name", text: $editingName)
                .textFieldStyle(.plain)
                .onSubmit {
                    let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onRenameProject(project, trimmed)
                    }
                    editingProjectID = nil
                }
                .onExitCommand {
                    editingProjectID = nil
                }
        } else {
            Text(project.name)
                .contextMenu {
                    Button("Rename…") {
                        editingName = project.name
                        editingProjectID = project.id
                    }

                    Button("Add Folder…") {
                        onAddDirectory(project)
                    }

                    Divider()

                    Button("Delete Project") {
                        onDeleteProject(project)
                    }
                }
        }
    }

    @ViewBuilder
    private func projectContent(for project: Project) -> some View {
        ForEach(project.directoryPaths, id: \.self) { dirPath in
            if let tree = treesByDirectory[dirPath] {
                OutlineGroup(tree, children: \.outlineChildren) { node in
                    if node.isDirectory {
                        directoryLabel(for: node, isRoot: node.path == dirPath, projectID: project.id)
                    } else {
                        fileRow(for: node)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(abbreviatedPath(dirPath))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Button {
            onAddDirectory(project)
        } label: {
            Label("Add Folder…", systemImage: "folder.badge.plus")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .controlSize(.small)
    }

    private func directoryLabel(
        for node: ProjectFileNode,
        isRoot: Bool,
        projectID: UUID
    ) -> some View {
        Label {
            Text(isRoot ? abbreviatedPath(node.path) : node.name)
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
        }
        .contextMenu {
            if isRoot {
                Button("Remove Folder") {
                    onRemoveDirectory(
                        projects.first { $0.id == projectID }!,
                        node.path
                    )
                }
            }

            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: node.path)
            }
        }
    }

    private func fileRow(for node: ProjectFileNode) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .leading)

            Text(node.name)
                .font(.body)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .tag(node.path)
        .contextMenu {
            Button("Open In New Window") {
                selectedPath = node.path
                onOpenInNewWindow(node)
            }

            Divider()

            Button("Reveal in Finder") {
                selectedPath = node.path
                NSWorkspace.shared.activateFileViewerSelecting([node.fileURL])
            }

            Button("Copy Path to File") {
                selectedPath = node.path
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(node.path, forType: .string)
            }
        }
        .draggable(node.path)
    }

    private func findFileNode(path: String) -> ProjectFileNode? {
        for (_, tree) in treesByDirectory {
            if let found = findInTree(tree, path: path) {
                return found
            }
        }

        return nil
    }

    private func findInTree(_ node: ProjectFileNode, path: String) -> ProjectFileNode? {
        if node.path == path {
            return node
        }

        for child in node.children {
            if let found = findInTree(child, path: path) {
                return found
            }
        }

        return nil
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }

        return path
    }
}
