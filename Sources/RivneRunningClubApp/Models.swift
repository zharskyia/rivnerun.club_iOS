import Foundation

struct NewsItem: Identifiable, Codable, Hashable {
    var id: String { articleUrl }
    let title: String
    let date: String
    let imageURL: String
    let summary: String
    let articleUrl: String
}

/// The archive page has no real excerpt, so a summary that's blank or just repeats
/// the title isn't shown — avoids a redundant line under the headline.
extension NewsItem {
    var excerpt: String? {
        summary.isEmpty || summary == title ? nil : summary
    }
}

/// The full text and photo gallery of one news article, fetched from its own page
/// (the archive only has a thumbnail and title). See `ClubSiteRepository.swift`.
struct NewsArticleContent: Codable, Equatable {
    let text: String
    let imageUrls: [String]
}

struct TrainingSession: Identifiable, Codable, Hashable {
    var id: String { day + date + time + title }
    let day: String
    let date: String
    let time: String
    let title: String
    let location: String
    let description: String
}

struct RaceItem: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let date: String
    let description: String
    let url: String
}

struct StoreItem: Identifiable, Codable, Hashable {
    var id: String { productUrl }
    let title: String
    let price: String
    let imageURL: String
    let productUrl: String
}

struct ContactLink: Identifiable {
    let id: Int
    let name: String
    let value: String
    let url: String
    let icon: String
    let tint: String
}

struct PartnerItem: Identifiable, Codable, Hashable {
    var id: String { websiteUrl }
    let logoUrl: String
    let websiteUrl: String
}

struct RecordGroup: Codable, Hashable {
    let heading: String
    let records: [String]
}

struct RecordsTab: Identifiable, Codable, Hashable {
    var id: String { title }
    let title: String
    let groups: [RecordGroup]
}

/// A snapshot of everything the app shows, either scraped live from rivnerun.club
/// or restored from the last successful fetch. See `ClubSiteRepository.swift`.
struct ClubSnapshot: Codable, Equatable {
    var homeDescription: String
    var clubDescription: String
    var news: [NewsItem]
    var training: [TrainingSession]
    var races: [RaceItem]
    var store: [StoreItem]
    var contacts: String
    var support: String
    var clubPages: [String: String]
    var records: [RecordsTab]
    var partners: [PartnerItem]
    var lastUpdated: Date?

    /// `false` until the first successful site fetch (first launch with no network),
    /// used to tell "the site genuinely has nothing" apart from "we haven't loaded yet".
    var hasLoadedSiteData: Bool { lastUpdated != nil }

    static let bundled = ClubSnapshot(
        homeDescription: "Біг для життя, рух для міста",
        clubDescription: "Rivne Running Club — бігова спільнота Рівного.",
        news: [
            NewsItem(
                title: "Андрій Ващук пробіг Берлінський марафон",
                date: "28.09.2026",
                imageURL: "https://rivnerun.club/img/500/20260928_8493.jpg",
                summary: "Великий фініш, рекордний темп і сильний дух клубу.",
                articleUrl: "https://rivnerun.club/andriy-vashchuk-probih-berlinskiy-marafon"
            ),
            NewsItem(
                title: "Rivne Running Club успішно фінішував трейл «Синьогора»",
                date: "27.09.2026",
                imageURL: "https://rivnerun.club/img/500/20260927_1711.jpeg",
                summary: "Команда показала стабільну форму та відвагу в гірському трейлі.",
                articleUrl: "https://rivnerun.club/rivne-running-club-uspishno-finishuvav-treyl-sinohora"
            ),
            NewsItem(
                title: "Омельчук перемогла у Вараші",
                date: "21.09.2026",
                imageURL: "https://rivnerun.club/img/500/20260921_5658.png",
                summary: "Нова перемога в серії клубних змагань",
                articleUrl: "https://rivnerun.club/omelchuk-peremohla-u-varashi"
            ),
            NewsItem(
                title: "Листок вчергове перемогла у Хусті та оновила рекорд клубу",
                date: "19.10.2026",
                imageURL: "https://rivnerun.club/img/500/20260919_1519.jpg",
                summary: "Нова вражаюча дистанція на 21,1 км з рекордним результатом.",
                articleUrl: "https://rivnerun.club/news"
            )
        ],
        // No fabricated training/races here: the schedule and race list go stale fast,
        // so a first launch with no network shows an honest empty state instead
        // (see `noUpcomingTrainingMessage` and `EventsView`'s empty-state message).
        training: [],
        races: [],
        store: [
            StoreItem(
                title: "Шорти жіночі", price: "730 грн.",
                imageURL: "https://rivnerun.club/img/1000/20250619_6488.jpg",
                productUrl: "https://rivnerun.club/tovar/shorti-zhinochi"
            ),
            StoreItem(
                title: "Шорти чоловічі", price: "760 грн.",
                imageURL: "https://rivnerun.club/img/1000/20250619_1183.jpg",
                productUrl: "https://rivnerun.club/tovar/shorti-"
            ),
            StoreItem(
                title: "Кепка", price: "325 грн.",
                imageURL: "https://rivnerun.club/img/1000/20240401_4071.jpg",
                productUrl: "https://rivnerun.club/tovar/kepka-chorna-ta-bila"
            ),
            StoreItem(
                title: "Бананка", price: "560 грн.",
                imageURL: "https://rivnerun.club/img/1000/20230607_6552.png",
                productUrl: "https://rivnerun.club/tovar/bananka"
            )
        ],
        contacts: "З питань співпраці, партнерства та інших питань – пишіть на електронну пошту rivnerun@gmail.com.\n\nДля оперативного зв’язку, запитань та пропозицій – телефонуйте на мобільний номер",
        support: "Якщо Ви маєте бажання підтримати Rivne Running Club благодійним внеском – ви можете зробити донат на будь-яку суму від 200 грн на цей номер картки Приватбанка: 5168752108112932 (картка на Ю.С.Ю.).\n\nЯкщо ви хочете в інший спосіб підтримати нашу команду – напишіть нам на електронну скриньку rivnerun@gmail.com.",
        clubPages: [:],
        records: [],
        partners: [],
        lastUpdated: nil
    )
}

let contactLinks: [ContactLink] = [
    ContactLink(id: 1, name: "Telegram", value: "@rivnerun", url: "https://t.me/rivnerun", icon: "paperplane.fill", tint: "#2AA6F5"),
    ContactLink(id: 2, name: "Instagram", value: "@rivnerun.club", url: "https://www.instagram.com/rivnerun.club/", icon: "camera.fill", tint: "#E1306C"),
    ContactLink(id: 3, name: "YouTube", value: "Rivne Running Club", url: "https://www.youtube.com/@rivnerunningclub726", icon: "play.rectangle.fill", tint: "#FF0000"),
    ContactLink(id: 4, name: "Facebook", value: "Rivne Running Club", url: "https://www.facebook.com/rivnerun.club/", icon: "f.square.fill", tint: "#1877F2"),
    ContactLink(id: 5, name: "Strava", value: "Club page", url: "https://www.strava.com/clubs/rivne-running-club-327192?hl=", icon: "figure.run", tint: "#FC4C02")
]

/// The first non-blank line of a multi-line description, used in preview cards.
func firstParagraph(_ text: String) -> String {
    text.split(separator: "\n", omittingEmptySubsequences: false)
        .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        .map(String.init) ?? text
}
