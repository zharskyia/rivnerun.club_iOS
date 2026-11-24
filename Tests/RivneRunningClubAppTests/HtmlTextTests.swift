import XCTest
@testable import RivneRunningClubApp

/// Mirrors Android's `HtmlTextTest.kt` — `plainText` should render an HTML fragment the
/// way a browser would (whitespace collapsed, `<br>`/block tags become line breaks).
final class HtmlTextTests: XCTestCase {
    func testDecodesNamedAndNumericEntities() {
        XCTAssertEqual(
            "«Синьогора» – 5 км & більше…",
            plainText("&laquo;Синьогора&raquo; &ndash; 5&nbsp;км &amp; більше&hellip;")
        )
        XCTAssertEqual("№1 '", plainText("&#8470;1 &#x27;"))
    }

    func testKeepsUnknownEntitiesAsIs() {
        XCTAssertEqual("&unknown; текст", plainText("&unknown; текст"))
    }

    func testCollapsesSourceWhitespaceLikeBrowser() {
        XCTAssertEqual("Субота 24 жовтня", plainText("\n\t\tСубота\t\t\t<strong>24 жовтня</strong>\n"))
    }

    func testBreaksLinesOnBrAndBlocks() {
        XCTAssertEqual("Перший\nДругий\nТретій", plainText("<p>Перший<br>Другий</p><p>Третій</p>"))
        XCTAssertEqual("Пункт 1\nПункт 2", plainText("<ul><li>Пункт 1</li><li>Пункт 2</li></ul>"))
    }

    func testDropsInvisibleCharactersAndEmptyLines() {
        XCTAssertEqual(
            "rivnerun@gmail.com",
            plainText("<p><br></p><a href=\"mailto:rivnerun@gmail.com\">rivnerun@gmail.com</a>\u{200B}\u{200B}")
        )
    }

    func testIgnoresScriptsAndStyles() {
        XCTAssertEqual("Текст", plainText("<style>p{color:red}</style><script>var a = 1;</script>Текст"))
    }

    func testFirstParagraphSkipsBlankLines() {
        XCTAssertEqual("Перший", firstParagraph("\n  \nПерший\nДругий"))
    }
}
