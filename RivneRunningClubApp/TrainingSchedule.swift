import Foundation

struct TrainingScheduleSplit {
    let upcoming: [TrainingSession]
    let past: [TrainingSession]
}

private let ukrainianMonthsGenitive = [
    "січня", "лютого", "березня", "квітня", "травня", "червня",
    "липня", "серпня", "вересня", "жовтня", "листопада", "грудня"
]

/// Start time of a training session. The site doesn't say the year ("25 жовтня"), so the
/// year closest to `now` is chosen — the schedule only ever covers the current week.
func trainingStartDate(_ session: TrainingSession, now: Date, calendar: Calendar = .current) -> Date? {
    guard let dateMatch = session.date.range(of: #"(\d{1,2})\s+(\p{L}+)"#, options: .regularExpression) else {
        return nil
    }
    let dateText = session.date[dateMatch]
    let dateParts = dateText.split(separator: " ", maxSplits: 1)
    guard dateParts.count == 2, let day = Int(dateParts[0]) else { return nil }
    guard let month = ukrainianMonthsGenitive.firstIndex(of: dateParts[1].lowercased()) else { return nil }

    guard let timeMatch = session.time.range(of: #"(\d{1,2}):(\d{2})"#, options: .regularExpression) else {
        return nil
    }
    let timeParts = session.time[timeMatch].split(separator: ":")
    guard timeParts.count == 2, let hour = Int(timeParts[0]), let minute = Int(timeParts[1]) else { return nil }

    let currentYear = calendar.component(.year, from: now)
    let candidates = (currentYear - 1...currentYear + 1).compactMap { year -> Date? in
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }
    return candidates.min(by: { abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) })
}

/// The site returns the week in reverse order along with sessions that already happened.
/// Sorts by time and separates past sessions; if any date can't be parsed, keeps the site's order.
func splitTrainingSchedule(
    _ sessions: [TrainingSession],
    now: Date,
    calendar: Calendar = .current
) -> TrainingScheduleSplit {
    let starts = sessions.map { trainingStartDate($0, now: now, calendar: calendar) }
    if starts.contains(where: { $0 == nil }) {
        return TrainingScheduleSplit(upcoming: sessions, past: [])
    }
    let sorted = zip(sessions, starts.map { $0! }).sorted { $0.1 < $1.1 }
    return TrainingScheduleSplit(
        upcoming: sorted.filter { $0.1 >= now }.map { $0.0 },
        past: sorted.filter { $0.1 < now }.map { $0.0 }
    )
}

/// Message for an empty upcoming list, distinguishing "nothing scheduled" from
/// "we haven't loaded the site yet" (first launch with no network).
func noUpcomingTrainingMessage(_ snapshot: ClubSnapshot) -> String {
    if !snapshot.training.isEmpty {
        return "Цього тижня тренувань більше не заплановано."
    }
    if snapshot.hasLoadedSiteData {
        return "На сайті клубу наразі немає запланованих тренувань."
    }
    return "Розклад тренувань з’явиться після підключення до Інтернету."
}
