import Foundation

enum RemoteDocumentFetcherError: Error {
    case invalidUTF8Response
}

enum RemoteDocumentFetcher {
    static func resolveForMarkdownRequest(_ requestedURL: URL) -> RemoteDocument {
        RemoteDocument(
            requestedURL: requestedURL,
            renderURL: resolveRenderURL(for: requestedURL)
        )
    }

    static func fetch(_ requestedURL: URL, session: URLSession = .shared) async throws -> RemoteDocument {
        let resolved = resolveForMarkdownRequest(requestedURL)
        let (data, response) = try await session.data(from: resolved.renderURL)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw RemoteDocumentFetcherError.invalidUTF8Response
        }

        return RemoteDocument(
            requestedURL: resolved.requestedURL,
            renderURL: resolved.renderURL,
            content: content
        )
    }

    private static func resolveRenderURL(for requestedURL: URL) -> URL {
        guard requestedURL.pathExtension.isEmpty else {
            return requestedURL
        }

        return requestedURL.appendingPathComponent("INDEX.md")
    }
}
