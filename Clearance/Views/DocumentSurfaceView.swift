import SwiftUI

struct DocumentSurfaceView: View {
    @ObservedObject var session: DocumentSession
    let parsedDocument: ParsedMarkdownDocument
    let headingScrollRequest: HeadingScrollRequest?
    @Binding var mode: WorkspaceMode

    var body: some View {
        switch mode {
        case .view:
            RenderedMarkdownView(
                document: parsedDocument,
                headingScrollRequest: headingScrollRequest
            )
        case .edit:
            CodeMirrorEditorView(
                text: Binding(
                    get: { session.content },
                    set: { session.content = $0 }
                )
            )
        }
    }
}
