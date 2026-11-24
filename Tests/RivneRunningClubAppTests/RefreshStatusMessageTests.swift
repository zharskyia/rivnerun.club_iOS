import XCTest
@testable import RivneRunningClubApp

/// Mirrors Android's `RefreshStatusTest.kt` — the top banner's message after a refresh.
final class RefreshStatusMessageTests: XCTestCase {
    private let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = kyiv
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private var now: Date { date(2026, 10, 23, 12, 0) }

    private var loaded: ClubSnapshot {
        var snapshot = ClubSnapshot.bundled
        snapshot.lastUpdated = date(2026, 10, 23, 9, 5)
        return snapshot
    }

    private func result(failed: Int) -> SiteRefreshResult {
        SiteRefreshResult(snapshot: loaded, errors: (0..<failed).map { "/page\($0): error" }, pageCount: 12)
    }

    func testNoMessageWhenEverythingUpdated() {
        XCTAssertNil(refreshStatusMessage(result(failed: 0), previous: loaded, now: now, calendar: calendar))
    }

    func testPartialFailureUsesUkrainianPlural() {
        XCTAssertEqual(
            "Не вдалося оновити 1 розділ — у ньому показано попередні дані.",
            refreshStatusMessage(result(failed: 1), previous: loaded, now: now, calendar: calendar)
        )
        XCTAssertEqual(
            "Не вдалося оновити 3 розділи — у них показано попередні дані.",
            refreshStatusMessage(result(failed: 3), previous: loaded, now: now, calendar: calendar)
        )
        XCTAssertEqual(
            "Не вдалося оновити 11 розділів — у них показано попередні дані.",
            refreshStatusMessage(result(failed: 11), previous: loaded, now: now, calendar: calendar)
        )
    }

    func testOfflineWithSavedDataShowsWhenItWasUpdated() {
        XCTAssertEqual(
            "Немає зв’язку із сайтом клубу. Показано дані, оновлені сьогодні о 09:05.",
            refreshStatusMessage(result(failed: 12), previous: loaded, now: now, calendar: calendar)
        )
    }

    func testOfflineOnFirstLaunchDoesNotMentionSavedData() {
        XCTAssertEqual(
            "Немає зв’язку із сайтом клубу. Дані з’являться після підключення до Інтернету.",
            refreshStatusMessage(result(failed: 12), previous: ClubSnapshot.bundled, now: now, calendar: calendar)
        )
    }

    func testFormatsYesterdayAndOlderDates() {
        XCTAssertEqual("учора о 23:50", formatUpdateTime(date(2026, 10, 22, 23, 50), now: now, calendar: calendar))
        XCTAssertEqual("20.10.2026 о 07:00", formatUpdateTime(date(2026, 10, 20, 7, 0), now: now, calendar: calendar))
    }
}
