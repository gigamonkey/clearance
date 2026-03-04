import Foundation

struct ParsedMarkdownDocument {
    let body: String
    let flattenedFrontmatter: [String: String]
}
