import XCTest
@testable import RivneRunningClubApp

/// Mirrors the applicable parts of Android's `ScrapeConfigTest.kt`. iOS falls back
/// group-by-group (not field-by-field like Android's kotlinx.serialization defaults) —
/// see `ScrapeConfig.init(from:)` — so a couple of these are iOS-specific rather than
/// direct ports; the shared-config tests (which both platforms care about) are identical.
final class ScrapeConfigTests: XCTestCase {
    private func sharedConfigData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "scrape-config", withExtension: "json", subdirectory: "Fixtures") else {
            throw FixtureError.missing("Fixtures/scrape-config.json")
        }
        return try Data(contentsOf: url)
    }

    func testDefaultConfigIsValid() {
        XCTAssertNil(ScrapeConfig.default.validationError())
    }

    func testSharedConfigCopyIsValid() throws {
        let config = try JSONDecoder().decode(ScrapeConfig.self, from: sharedConfigData())
        XCTAssertNil(config.validationError())
    }

    /// iOS falls back to the built-in default for a whole section if even one field is
    /// missing in it, so the shared config (`scrape-config.json`, maintained in the
    /// `rivnerun_api` repo together with Android) must list every field of every section —
    /// the same reason Android keeps `sharedConfigCopyListsEveryField`.
    func testSharedConfigCopyListsEveryField() throws {
        let shared = try JSONSerialization.jsonObject(with: sharedConfigData()) as? [String: Any]
        let expected = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ScrapeConfig.default)) as? [String: Any]
        let sharedDict = try XCTUnwrap(shared)
        let expectedDict = try XCTUnwrap(expected)

        XCTAssertEqual(Set(expectedDict.keys), Set(sharedDict.keys))
        for (section, fields) in expectedDict {
            guard let expectedFields = fields as? [String: Any] else { continue }
            let sharedFields = sharedDict[section] as? [String: Any] ?? [:]
            XCTAssertEqual(Set(expectedFields.keys), Set(sharedFields.keys), "section \(section)")
        }
    }

    func testMissingSectionFallsBackToDefaultForThatSectionOnly() throws {
        let json = """
        {"news": {"articleLink": "a", "image": "b", "title": "(?is)<b>(.*?)</b>", "date": "d"}}
        """
        let config = try JSONDecoder().decode(ScrapeConfig.self, from: Data(json.utf8))
        XCTAssertEqual("(?is)<b>(.*?)</b>", config.news.title)
        XCTAssertEqual(ScrapeConfig.default.training, config.training)
        XCTAssertEqual(ScrapeConfig.default.races, config.races)
    }

    /// Documents the iOS-specific (coarser-grained) fallback: a *present but incomplete*
    /// section falls back entirely, including the fields it did specify — unlike Android,
    /// which keeps the specified fields and defaults only the missing ones.
    func testIncompleteSectionFallsBackEntirely() throws {
        let json = #"{"news": {"title": "(?is)<b>(.*?)</b>"}}"#
        let config = try JSONDecoder().decode(ScrapeConfig.self, from: Data(json.utf8))
        XCTAssertEqual(ScrapeConfig.default.news, config.news)
        XCTAssertNotEqual("(?is)<b>(.*?)</b>", config.news.title)
    }

    func testUnknownTopLevelSectionIsIgnored() throws {
        let json = #"{"home": {"descriptionMeta": "(?is)<b>(.*?)</b>"}, "unknownSection": {}}"#
        let config = try JSONDecoder().decode(ScrapeConfig.self, from: Data(json.utf8))
        XCTAssertEqual("(?is)<b>(.*?)</b>", config.home.descriptionMeta)
    }

    func testCachedConfigRoundTrips() throws {
        let encoded = try JSONEncoder().encode(ScrapeConfig.default)
        let decoded = try JSONDecoder().decode(ScrapeConfig.self, from: encoded)
        XCTAssertEqual(ScrapeConfig.default, decoded)
    }

    func testConfigWithBrokenRegexIsRejected() {
        var config = ScrapeConfig.default
        config.news.title = "(?is)<strong[^>*>(.*?)</strong>"
        XCTAssertNotNil(config.validationError())
    }

    func testConfigWithMissingCaptureGroupIsRejected() {
        var config = ScrapeConfig.default
        config.races.link = #"(?is)<a\b[^>]*href=["']([^"']+)["'][^>]*>.*?</a>"#
        XCTAssertNotNil(config.validationError())
    }
}
