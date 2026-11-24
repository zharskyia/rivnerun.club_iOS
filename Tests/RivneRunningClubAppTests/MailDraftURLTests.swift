import XCTest
@testable import RivneRunningClubApp

/// `mailDraftURL` plays the same role as Android's `mailtoUri` (encode subject/body
/// directly into the link, skip empty parameters), but percent-encodes via Foundation
/// rather than Java's `URLEncoder`, so these cases are hand-traced against iOS's own
/// encoding rather than ported from Android's Kotlin-specific expected strings.
final class MailDraftURLTests: XCTestCase {
    func testSkipsEmptyParameters() {
        XCTAssertEqual(
            "mailto:rivnerun@gmail.com?subject=Hi",
            mailDraftURL(subject: "Hi", body: "")?.absoluteString
        )
    }

    func testNoQueryAtAllWhenBothEmpty() {
        XCTAssertEqual(
            "mailto:rivnerun@gmail.com",
            mailDraftURL(subject: "", body: "")?.absoluteString
        )
    }

    func testEncodesDelimiterCharactersInValues() {
        XCTAssertEqual(
            "mailto:rivnerun@gmail.com?subject=A%26B&body=x%3Dy",
            mailDraftURL(subject: "A&B", body: "x=y")?.absoluteString
        )
    }

    func testEncodesSpacesAndNewlines() {
        XCTAssertEqual(
            "mailto:rivnerun@gmail.com?subject=a%20b&body=line1%0Aline2",
            mailDraftURL(subject: "a b", body: "line1\nline2")?.absoluteString
        )
    }

    func testCyrillicSubjectIsPercentEncodedNotRaw() {
        let url = mailDraftURL(subject: "Заявка", body: "")
        XCTAssertNotNil(url)
        let string = try XCTUnwrap(url?.absoluteString)
        XCTAssertTrue(string.hasPrefix("mailto:rivnerun@gmail.com?subject=%D0%97"), "Got: \(string)")
        XCTAssertFalse(string.contains("Заявка"))
    }
}
