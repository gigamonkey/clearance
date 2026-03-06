import SwiftUI

struct AddressBarView: View {
    let activeURL: URL?
    let isLoading: Bool
    let onCommit: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Enter path or URL", text: $text)
                .focused($isFocused)
                .onSubmit {
                    onCommit(text)
                }

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(minWidth: 280, idealWidth: 460, maxWidth: 640)
        .onAppear {
            syncText()
        }
        .onChange(of: isFocused) { _, _ in
            syncText()
        }
        .onChange(of: activeURL) { _, _ in
            syncText()
        }
    }

    private func syncText() {
        if isFocused {
            text = AddressBarFormatter.editingText(for: activeURL)
        } else {
            text = AddressBarFormatter.displayText(for: activeURL)
        }
    }
}
