import Foundation
import Yams

struct FrontmatterParser {
    private let frontmatterRegex = try! NSRegularExpression(pattern: #"(?s)\A---\R(.*?)\R---\R?"#)

    func parse(markdown: String) -> ParsedMarkdownDocument {
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)

        guard let match = frontmatterRegex.firstMatch(in: markdown, options: [], range: range),
              let yamlRange = Range(match.range(at: 1), in: markdown),
              let fullRange = Range(match.range(at: 0), in: markdown) else {
            return ParsedMarkdownDocument(body: markdown, flattenedFrontmatter: [:])
        }

        let yamlText = String(markdown[yamlRange])
        let frontmatterObject = (try? Yams.load(yaml: yamlText)) ?? nil
        let flattened = flatten(frontmatterObject)
        let body = String(markdown[fullRange.upperBound...])

        return ParsedMarkdownDocument(body: body, flattenedFrontmatter: flattened)
    }

    private func flatten(_ object: Any?) -> [String: String] {
        guard let object else {
            return [:]
        }

        var flattened: [String: String] = [:]
        flatten(object, prefix: "", into: &flattened)
        return flattened
    }

    private func flatten(_ value: Any, prefix: String, into result: inout [String: String]) {
        if let dictionary = dictionaryValue(from: value) {
            for (key, nested) in dictionary {
                let nestedPrefix = prefix.isEmpty ? key : "\(prefix).\(key)"
                flatten(nested, prefix: nestedPrefix, into: &result)
            }
            return
        }

        if let array = value as? [Any] {
            for (index, nested) in array.enumerated() {
                let nestedPrefix = "\(prefix)[\(index)]"
                flatten(nested, prefix: nestedPrefix, into: &result)
            }
            return
        }

        result[prefix] = scalarDescription(value)
    }

    private func dictionaryValue(from value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }

        if let dictionary = value as? [AnyHashable: Any] {
            var converted: [String: Any] = [:]
            for (key, nestedValue) in dictionary {
                converted[String(describing: key)] = nestedValue
            }
            return converted
        }

        return nil
    }

    private func scalarDescription(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }

        return String(describing: value)
    }
}
