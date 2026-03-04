import XCTest
@testable import Clearance

final class FrontmatterParserTests: XCTestCase {
    func testParsesFrontmatterAndBody() {
        let markdown = """
        ---
        title: Sample
        tags:
          - one
          - two
        ---
        # Heading

        body text
        """

        let parsed = FrontmatterParser().parse(markdown: markdown)

        XCTAssertEqual(parsed.body, "# Heading\n\nbody text")
        XCTAssertEqual(parsed.flattenedFrontmatter["title"], "Sample")
        XCTAssertEqual(parsed.flattenedFrontmatter["tags[0]"], "one")
        XCTAssertEqual(parsed.flattenedFrontmatter["tags[1]"], "two")
    }

    func testLeavesMarkdownUntouchedWhenNoFrontmatter() {
        let markdown = "# Hello\n\nworld"

        let parsed = FrontmatterParser().parse(markdown: markdown)

        XCTAssertEqual(parsed.body, markdown)
        XCTAssertTrue(parsed.flattenedFrontmatter.isEmpty)
    }

    func testFlattensNestedObjectsAndArrays() {
        let markdown = """
        ---
        seo:
          title: Deep
          keywords:
            - alpha
            - beta
        nested:
          object:
            value: 12
        ---
        Body
        """

        let parsed = FrontmatterParser().parse(markdown: markdown)

        XCTAssertEqual(parsed.flattenedFrontmatter["seo.title"], "Deep")
        XCTAssertEqual(parsed.flattenedFrontmatter["seo.keywords[0]"], "alpha")
        XCTAssertEqual(parsed.flattenedFrontmatter["seo.keywords[1]"], "beta")
        XCTAssertEqual(parsed.flattenedFrontmatter["nested.object.value"], "12")
    }
}
