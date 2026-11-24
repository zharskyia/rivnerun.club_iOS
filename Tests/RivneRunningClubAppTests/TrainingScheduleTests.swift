import XCTest
@testable import RivneRunningClubApp

/// Mirrors Android's `TrainingScheduleTest.kt`. The site gives dates without a year
/// ("25 жовтня"), so `trainingStartDate` has to guess the nearest one to `now`.
final class TrainingScheduleTests: XCTestCase {
    private let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = kyiv
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func session(_ day: String, _ date: String, _ time: String, _ title: String) -> TrainingSession {
        TrainingSession(day: day, date: date, time: time, title: title, location: "", description: "")
    }

    func testParsesUkrainianDateWithinCurrentWeek() {
        let now = date(2026, 10, 23, 12, 0)
        XCTAssertEqual(
            date(2026, 10, 25, 9, 10),
            trainingStartDate(session("Неділя", "25 жовтня", "09:10", "Біг"), now: now, calendar: calendar)
        )
    }

    func testPicksNextYearAcrossNewYear() {
        let now = date(2026, 12, 30, 12, 0)
        XCTAssertEqual(
            date(2027, 1, 2, 9, 0),
            trainingStartDate(session("Субота", "2 січня", "09:00", "Біг"), now: now, calendar: calendar)
        )
    }

    func testUnknownDateFormatGivesNil() {
        XCTAssertNil(
            trainingStartDate(session("Неділя", "завтра", "09:10", "Біг"), now: date(2026, 1, 1, 0, 0), calendar: calendar)
        )
    }

    func testSplitsSiteOrderIntoUpcomingAndPastChronologically() {
        let siteOrder = [
            session("Неділя", "25 жовтня", "09:10", "Пробіжка"),
            session("Субота", "24 жовтня", "09:02", "Ходьба"),
            session("Субота", "24 жовтня", "08:30", "Йога"),
            session("Середа", "21 жовтня", "19:15", "Відкрите"),
            session("Вівторок", "20 жовтня", "19:15", "Променад")
        ]
        let schedule = splitTrainingSchedule(siteOrder, now: date(2026, 10, 23, 12, 0), calendar: calendar)
        XCTAssertEqual(["Йога", "Ходьба", "Пробіжка"], schedule.upcoming.map(\.title))
        XCTAssertEqual(["Променад", "Відкрите"], schedule.past.map(\.title))
    }

    func testKeepsSiteOrderWhenADateCannotBeParsed() {
        let sessions = [
            session("Неділя", "25 жовтня", "09:10", "А"),
            session("?", "колись", "", "Б")
        ]
        let schedule = splitTrainingSchedule(sessions, now: date(2026, 10, 23, 12, 0), calendar: calendar)
        XCTAssertEqual(sessions, schedule.upcoming)
        XCTAssertEqual([], schedule.past)
    }
}
