import XCTest
@testable import RivneRunningClubApp

/// Mirrors the round-trip part of Android's `SnapshotSerializationTest.kt` (its legacy-cache
/// test has no iOS equivalent: this code has never shipped, so there's no old cache format
/// to stay compatible with).
final class SnapshotCodableTests: XCTestCase {
    func testSnapshotSurvivesRoundTrip() throws {
        var snapshot = ClubSnapshot.bundled
        snapshot.training = [
            TrainingSession(day: "Неділя", date: "25 жовтня", time: "09:10", title: "Пробіжка", location: "Парк Шевченка.", description: "")
        ]
        snapshot.races = [RaceItem(id: 1, title: "Забіг", date: "1 листопада", description: "Опис", url: "https://rivnerun.club/zabig")]
        snapshot.clubPages = ["/istoriya": "Історія клубу"]
        snapshot.records = [RecordsTab(title: "Аматори", groups: [RecordGroup(heading: "ЧОЛОВІКИ", records: ["42195 м – 2:56:06"])])]
        snapshot.partners = [PartnerItem(logoUrl: "https://rivnerun.club/img/500/logo.jpg", websiteUrl: "https://gerasport.com")]
        snapshot.lastUpdated = Date(timeIntervalSince1970: 1_790_000_000)

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ClubSnapshot.self, from: encoded)
        XCTAssertEqual(snapshot, decoded)
    }

    func testArticleContentRoundTrips() throws {
        let article = NewsArticleContent(text: "Текст", imageUrls: ["https://rivnerun.club/img/1000/a.jpg"])
        let encoded = try JSONEncoder().encode(article)
        let decoded = try JSONDecoder().decode(NewsArticleContent.self, from: encoded)
        XCTAssertEqual(article, decoded)
    }
}
