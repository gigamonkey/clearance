import AppKit
import SwiftUI

struct WorkspaceView: View {
    @StateObject private var viewModel: WorkspaceViewModel
    @State private var isPopOutDropTargeted = false
    @State private var isOutlineVisible = true
    @State private var headingScrollSequence = 0
    @State private var headingScrollRequest: HeadingScrollRequest?
    private let popoutWindowController: PopoutWindowController

    init(
        appSettings: AppSettings = AppSettings(),
        popoutWindowController: PopoutWindowController = PopoutWindowController()
    ) {
        _viewModel = StateObject(wrappedValue: WorkspaceViewModel(appSettings: appSettings))
        self.popoutWindowController = popoutWindowController
    }

    var body: some View {
        NavigationSplitView {
            RecentFilesSidebar(
                entries: viewModel.recentFilesStore.entries,
                selectedPath: $viewModel.selectedRecentPath,
                onOpenFile: { viewModel.promptAndOpenFile() }
            ) { entry in
                selectRecentEntry(entry)
            } onOpenInNewWindow: { entry in
                popOut(entry: entry)
            }
        } detail: {
            Group {
                if let session = viewModel.activeSession {
                    let parsed = FrontmatterParser().parse(markdown: session.content)
                    HSplitView {
                        DocumentSurfaceView(
                            session: session,
                            parsedDocument: parsed,
                            headingScrollRequest: headingScrollRequest,
                            mode: $viewModel.mode
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if shouldShowOutline(for: parsed) {
                            MarkdownOutlineView(headings: parsed.headings) { heading in
                                requestScroll(to: heading)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.snappy(duration: 0.2), value: shouldShowOutline(for: parsed))
                } else {
                    ContentUnavailableView {
                        Label("Open a Markdown File", systemImage: "doc.text")
                    } description: {
                        Text("Choose a file from the sidebar, or open one directly.")
                    } actions: {
                        Button("Open Markdown…") {
                            viewModel.promptAndOpenFile()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                if isPopOutDropTargeted {
                    Label("Drop To Pop Out", systemImage: "arrow.up.forward.square")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.thinMaterial, in: Capsule())
                        .padding(12)
                }
            }
            .dropDestination(for: String.self) { items, _ in
                guard let path = items.first else {
                    return false
                }

                return popOutDraggedPath(path)
            } isTargeted: { isTargeted in
                isPopOutDropTargeted = isTargeted
            }
            .navigationTitle(viewModel.windowTitle)
            .alert("File Changed On Disk", isPresented: Binding(
                get: { viewModel.externalChangeDocumentName != nil },
                set: { _ in }
            ), actions: {
                Button("Reload") {
                    viewModel.reloadActiveFromDisk()
                }
                Button("Keep Current", role: .cancel) {
                    viewModel.keepCurrentVersionAfterExternalChange()
                }
            }, message: {
                Text("“\(viewModel.externalChangeDocumentName ?? "This file")” changed outside Clearance.")
            })
        }
        .focusedSceneValue(\.workspaceCommandActions, WorkspaceCommandActions(
            openFile: { viewModel.promptAndOpenFile() },
            toggleOutline: { if viewModel.activeSession != nil { isOutlineVisible.toggle() } },
            showViewMode: { if viewModel.activeSession != nil { viewModel.mode = .view } },
            showEditMode: { if viewModel.activeSession != nil { viewModel.mode = .edit } },
            openInNewWindow: { popOutActiveSession() },
            findInDocument: { performFindInDocument() },
            printDocument: { performPrint() },
            hasActiveSession: viewModel.activeSession != nil,
            hasVisibleOutline: isOutlineVisible,
            canShowOutline: viewModel.mode == .view && !(viewModel.activeSession.map { FrontmatterParser().parse(markdown: $0.content).headings.isEmpty } ?? true)
        ))
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    isOutlineVisible.toggle()
                } label: {
                    Label(
                        isOutlineVisible ? "Hide Outline" : "Show Outline",
                        systemImage: "sidebar.right"
                    )
                }
                .disabled(viewModel.activeSession == nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.mode = viewModel.mode == .view ? .edit : .view
                } label: {
                    Label(
                        viewModel.mode == .edit ? "Done" : "Edit",
                        systemImage: viewModel.mode == .edit ? "checkmark" : "square.and.pencil"
                    )
                }
                .disabled(viewModel.activeSession == nil)
            }
        }
        .onChange(of: viewModel.activeSession?.id) { _, _ in
            headingScrollRequest = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearanceOpenURLs)) { notification in
            guard let urls = notification.object as? [URL],
                  let firstURL = urls.first else {
                return
            }

            viewModel.open(url: firstURL)
        }
        .alert("Could Not Open File", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        ), actions: {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
    }

    private func popOutActiveSession() {
        guard let session = viewModel.activeSession else {
            return
        }

        popoutWindowController.openWindow(for: session, mode: viewModel.mode)
    }

    private func popOut(entry: RecentFileEntry) {
        if let session = viewModel.open(recentEntry: entry) {
            popoutWindowController.openWindow(for: session, mode: viewModel.mode)
        }
    }

    private func selectRecentEntry(_ entry: RecentFileEntry) {
        let activePath = viewModel.activeSession?.url.standardizedFileURL.path
        if activePath == entry.path {
            viewModel.selectedRecentPath = entry.path
            return
        }

        viewModel.open(recentEntry: entry)
    }

    private func popOutDraggedPath(_ path: String) -> Bool {
        if let entry = viewModel.recentFilesStore.entries.first(where: { $0.path == path }) {
            popOut(entry: entry)
            return true
        }

        let url = URL(fileURLWithPath: path)
        guard let session = viewModel.open(url: url) else {
            return false
        }

        popoutWindowController.openWindow(for: session, mode: viewModel.mode)
        return true
    }

    private func requestScroll(to heading: MarkdownHeading) {
        headingScrollSequence += 1
        headingScrollRequest = HeadingScrollRequest(
            headingIndex: heading.index,
            sequence: headingScrollSequence
        )
    }

    private func shouldShowOutline(for parsed: ParsedMarkdownDocument) -> Bool {
        isOutlineVisible && viewModel.mode == .view && !parsed.headings.isEmpty
    }

    private func performFindInDocument() -> Bool {
        let findMenuItem = NSMenuItem()
        findMenuItem.tag = NSTextFinder.Action.showFindInterface.rawValue
        if NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: findMenuItem) {
            return true
        }

        let legacyFindMenuItem = NSMenuItem()
        legacyFindMenuItem.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        return NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: legacyFindMenuItem)
    }

    private func performPrint() -> Bool {
        NSApp.sendAction(#selector(NSView.printView(_:)), to: nil, from: nil)
    }
}

struct MarkdownOutlineView: View {
    let headings: [MarkdownHeading]
    let onSelectHeading: (MarkdownHeading) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Outline")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            List(headings) { heading in
                Button {
                    onSelectHeading(heading)
                } label: {
                    Text(heading.title)
                        .lineLimit(1)
                        .padding(.leading, CGFloat(max(0, heading.level - 1)) * 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help(heading.title)
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
    }
}
