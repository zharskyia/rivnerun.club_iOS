import XCTest
@testable import RivneRunningClubApp

/// Mirrors Android's `SiteParsersTest.kt`, against the exact same saved rivnerun.club
/// pages (October 2026) copied from the Android project's fixtures — both apps parse the
/// same site with the same shared `scrape-config.json` patterns, so they should agree.
final class SiteParsersTests: XCTestCase {
    private let config = ScrapeConfig.default

    func testHomeDescription() throws {
        let description = try parseHomeDescription(fixturePage("home"), config: config)
        XCTAssertTrue(
            description.hasPrefix("Rivne Running Club – біговий клуб м.Рівне та Рівненщини, головною метою якого"),
            "Got: \(description.prefix(80))"
        )
    }

    func testTrainingSchedule() throws {
        let sessions = try parseTraining(fixturePage("training"), config: config)
        XCTAssertEqual(5, sessions.count)
        XCTAssertEqual(
            TrainingSession(day: "Неділя", date: "25 жовтня", time: "09:10", title: "Пробіжка вихідного дня", location: "Парк Шевченка.", description: ""),
            sessions.first
        )
        XCTAssertEqual("Йога від Rivne Running Club", sessions[2].title)
        XCTAssertEqual("Стадіон НУВГП. Легкий біг, силові вправи.", sessions[3].location)
    }

    func testNewsArchive() throws {
        let news = try parseNewsArchive(fixturePage("news"), config: config)
        XCTAssertEqual(172, news.count)
        XCTAssertEqual(
            NewsItem(
                title: "Лисюк вчергове перемогла у Хусті та оновила рекорд клубу",
                date: "19.10.2026",
                imageURL: "https://rivnerun.club/img/500/20261019_6160.JPG",
                summary: "",
                articleUrl: "https://rivnerun.club/lisyuk-vcherhove-peremohla-u-khusti-ta-onovila-rekord-klubu"
            ),
            news.first
        )
    }

    func testNewsArticleTextAndPhotos() throws {
        let article = try parseNewsArticle(fixturePage("article"), config: config)
        XCTAssertEqual(
            [
                "Бігун Rivne Running Club Андрій Ващук пробіг один із найвідоміших забігів світу – Берлінський марафон.",
                "Ця подія щороку відбувається у Німеччині, має дуже швидку трасу, а також цей марафон є одним із Majorів, тобто головних марафонів світу.",
                "Андрій Ващук успішно подолав дистанцію у 42 кілометри 195 метрів з результатом 4 години 02 хвилини та 48 секунд.",
                "Цей результат дозволив Андрію посісти 17047-ме місце серед чоловіків і 526-те місце у віковій категорії 60+ років.",
                "Вітаємо Андрія та пишаємося його досягненнями. Чекаємо вдома!"
            ],
            article.text.components(separatedBy: "\n")
        )
        XCTAssertEqual(5, article.imageUrls.count)
        XCTAssertEqual("https://rivnerun.club/img/1000/20260928_8493.jpg", article.imageUrls.first)
    }

    func testStoreCatalog() throws {
        let products = try parseProducts(fixturePage("shop"), config: config)
        XCTAssertEqual(14, products.count)
        XCTAssertEqual(
            StoreItem(
                title: "Футболка чоловіча. Чорна",
                price: "660 ₴",
                imageURL: "https://rivnerun.club/img/1000/20230607_5329.jpg",
                productUrl: "https://rivnerun.club/tovar/futbolka-cholovicha-chorna"
            ),
            products.first
        )
    }

    func testClubRecordsTabs() throws {
        let tabs = parseRecords(try fixturePage("records"), config: config)
        XCTAssertEqual(["Аматори", "Засновники"], tabs.map(\.title))
        let amateurs = tabs[0].groups
        XCTAssertEqual(["ЧОЛОВІКИ", "ЖІНКИ"], amateurs.map(\.heading))
        XCTAssertEqual("42195 м – 2:56:06 – Юрій Зимоглядов (Хуст, 2024)", amateurs[0].records.first)
        XCTAssertEqual(6, amateurs[0].records.count)
        XCTAssertEqual(7, amateurs[1].records.count)
        XCTAssertEqual(
            ["Ольга ЗЕМЛЯК, ЗМС", "Наталія КРОЛЬ, ЗМС", "Ольга КОТОВСЬКА, МСМК", "Світлана СТАНКО, МСМК"],
            tabs[1].groups.map(\.heading)
        )
    }

    func testPartners() throws {
        XCTAssertEqual(
            [PartnerItem(logoUrl: "https://rivnerun.club/img/500/20230527_9780.jpg", websiteUrl: "https://gerasport.com")],
            parsePartners(try fixturePage("partners"), config: config)
        )
    }

    func testEmptyRaceListIsNotAnError() throws {
        XCTAssertEqual([], try parseRaces(fixturePage("events"), config: config))
    }

    func testContactsTextHasNoInvisibleCharacters() throws {
        XCTAssertEqual(
            "З питань співпраці, партнерства та інших питань – пишіть на електронну пошту rivnerun@gmail.com\n"
                + "Для оперативного зв’язку, запитань та пропозицій – телефонуйте на мобільний номер",
            try parseArticleText(fixturePage("contacts"), pageName: "сторінку контактів", config: config)
        )
    }

    func testDonateTextKeepsCardNumber() throws {
        let text = try parseArticleText(fixturePage("donate"), pageName: "сторінку підтримки", config: config)
        XCTAssertTrue(text.contains("на цей номер картки Приватбанка: 5168752108112932 (картка на Ю.С.Ю.)."))
        XCTAssertTrue(text.hasSuffix("напишіть нам на електронну скриньку rivnerun@gmail.com"))
    }
}
