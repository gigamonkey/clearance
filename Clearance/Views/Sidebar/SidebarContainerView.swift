import SwiftUI

enum SidebarTab: String, CaseIterable {
    case history = "History"
    case projects = "Projects"
}

struct SidebarContainerView: View {
    @Binding var selectedTab: SidebarTab

    let recentEntries: [RecentFileEntry]
    @Binding var selectedRecentPath: String?
    let onOpenFile: () -> Void
    let onDropURL: (URL) -> Bool
    let onSelectRecentEntry: (RecentFileEntry) -> Void
    let onOpenRecentInNewWindow: (RecentFileEntry) -> Void
    let onRemoveFromHistory: (RecentFileEntry) -> Void

    let projects: [Project]
    let treesByDirectory: [String: ProjectFileNode]
    @Binding var selectedProjectFilePath: String?
    let expansionState: SidebarExpansionState
    let expandedPaths: Set<String>
    let onSelectProjectFile: (ProjectFileNode) -> Void
    let onOpenProjectFileInNewWindow: (ProjectFileNode) -> Void
    let onCreateProject: () -> UUID?
    let onRenameProject: (Project, String) -> Void
    let onDeleteProject: (Project) -> Void
    let onAddDirectory: (Project) -> Void
    let onRemoveDirectory: (Project, String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)

            switch selectedTab {
            case .history:
                RecentFilesSidebar(
                    entries: recentEntries,
                    selectedPath: $selectedRecentPath,
                    onOpenFile: onOpenFile,
                    onDropURL: onDropURL,
                    onSelect: onSelectRecentEntry,
                    onOpenInNewWindow: onOpenRecentInNewWindow,
                    onRemoveFromSidebar: onRemoveFromHistory
                )
            case .projects:
                ProjectsSidebar(
                    projects: projects,
                    treesByDirectory: treesByDirectory,
                    selectedPath: $selectedProjectFilePath,
                    expansionState: expansionState,
                    expandedPaths: expandedPaths,
                    onSelectFile: onSelectProjectFile,
                    onOpenInNewWindow: onOpenProjectFileInNewWindow,
                    onCreateProject: onCreateProject,
                    onRenameProject: onRenameProject,
                    onDeleteProject: onDeleteProject,
                    onAddDirectory: onAddDirectory,
                    onRemoveDirectory: onRemoveDirectory
                )
            }
        }
    }
}
