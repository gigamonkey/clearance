import AppKit
import Combine
import SwiftUI

@MainActor
final class PopoutWindowController {
    private var windows: [NSWindow] = []
    private var windowDelegates: [ObjectIdentifier: PopoutWindowDelegate] = [:]
    private var titleSubscriptions: [ObjectIdentifier: AnyCancellable] = [:]

    func openWindow(for session: DocumentSession, mode: WorkspaceMode) {
        let content = PopoutDocumentView(session: session, initialMode: mode)
        let hostingController = NSHostingController(rootView: content)

        let window = NSWindow(contentViewController: hostingController)
        window.title = session.displayTitle
        window.setContentSize(NSSize(width: 980, height: 760))
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.closable)
        window.styleMask.insert(.miniaturizable)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        let windowID = ObjectIdentifier(window)

        let titleSubscription = session.$isDirty
            .receive(on: RunLoop.main)
            .sink { [weak window, weak session] _ in
                guard let window, let session else {
                    return
                }

                window.title = session.displayTitle
            }
        titleSubscriptions[windowID] = titleSubscription

        let windowDelegate = PopoutWindowDelegate { [weak self, weak window] in
            guard let self, let window else {
                return
            }
            self.removeWindow(window)
        }
        window.delegate = windowDelegate
        windowDelegates[windowID] = windowDelegate

        windows.append(window)
    }

    private func removeWindow(_ window: NSWindow) {
        let windowID = ObjectIdentifier(window)
        windows.removeAll { $0 === window }
        windowDelegates.removeValue(forKey: windowID)
        titleSubscriptions.removeValue(forKey: windowID)
    }
}

@MainActor
private final class PopoutWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

private struct PopoutDocumentView: View {
    @ObservedObject var session: DocumentSession
    @State private var mode: WorkspaceMode
    @State private var isOutlineVisible = true
    @State private var headingScrollSequence = 0
    @State private var headingScrollRequest: HeadingScrollRequest?

    init(session: DocumentSession, initialMode: WorkspaceMode) {
        self.session = session
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        let parsed = FrontmatterParser().parse(markdown: session.content)
        HSplitView {
            DocumentSurfaceView(
                session: session,
                parsedDocument: parsed,
                headingScrollRequest: headingScrollRequest,
                mode: $mode
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isOutlineVisible && mode == .view && !parsed.headings.isEmpty {
                MarkdownOutlineView(headings: parsed.headings) { heading in
                    headingScrollSequence += 1
                    headingScrollRequest = HeadingScrollRequest(
                        headingIndex: heading.index,
                        sequence: headingScrollSequence
                    )
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.2), value: isOutlineVisible && mode == .view && !parsed.headings.isEmpty)
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
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    mode = mode == .view ? .edit : .view
                } label: {
                    Label(
                        mode == .edit ? "Done" : "Edit",
                        systemImage: mode == .edit ? "checkmark" : "square.and.pencil"
                    )
                }
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .onChange(of: session.id) { _, _ in
            headingScrollRequest = nil
        }
    }
}
