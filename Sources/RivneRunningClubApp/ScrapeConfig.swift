import Foundation

/// URL звідки застосунок тягне актуальні правила скрейпінгу (регулярки).
/// Той самий спільний конфіг, яким користується Android-версія, тож зміни
/// в regex-правилах можна вносити без випуску нової версії застосунку.
/// Поки URL не налаштований або недоступний, застосунок безпечно працює
/// на вбудованих значеннях за замовчуванням [ScrapeConfig.default].
private let scrapeConfigURL = URL(string: "https://raw.githubusercontent.com/zharskyia/rivnerun_api/main/scrape-config.json")!
private let scrapeConfigCacheKey = "scrape_config_cache"

struct ScrapeConfig: Codable, Equatable {
    struct Home: Codable, Equatable {
        var descriptionMeta: String
    }

    struct Article: Codable, Equatable {
        var articleTag: String
        var bodyDivMarker: String
        var image: String
    }

    struct News: Codable, Equatable {
        var articleLink: String
        var image: String
        var title: String
        var date: String
    }

    struct Training: Codable, Equatable {
        var table: String
        var row: String
        var cell: String
        var firstParagraph: String
        var date: String
        var time: String
        var removeStrong: String
        var removeSpan: String
        var paragraph: String
    }

    struct Races: Codable, Equatable {
        var listDivMarker: String
        var link: String
        var titleStrong: String
        var titleHeading: String
        var date: String
    }

    struct Products: Codable, Equatable {
        var link: String
        var image: String
        var title: String
        var price: String
    }

    struct Records: Codable, Equatable {
        var tabsList: String
        var tabTitle: String
        var tabsContentMarker: String
        var paragraph: String
    }

    struct Partners: Codable, Equatable {
        var listDivMarker: String
        var link: String
        var image: String
    }

    var version: Int
    var home: Home
    var article: Article
    var news: News
    var training: Training
    var races: Races
    var products: Products
    var records: Records
    var partners: Partners

    private enum CodingKeys: String, CodingKey {
        case version, home, article, news, training, races, products, records, partners
    }

    /// Falls back field-group-by-field-group to `default` instead of rejecting the whole
    /// document, so a remote config that's missing or has reshaped one group (e.g. the
    /// server adds a new section later) still applies everywhere else — mirrors Android's
    /// `decodeScrapeConfig`, which merges per key instead of failing the whole parse.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = ScrapeConfig.default
        version = (try? container.decode(Int.self, forKey: .version)) ?? fallback.version
        home = (try? container.decode(Home.self, forKey: .home)) ?? fallback.home
        article = (try? container.decode(Article.self, forKey: .article)) ?? fallback.article
        news = (try? container.decode(News.self, forKey: .news)) ?? fallback.news
        training = (try? container.decode(Training.self, forKey: .training)) ?? fallback.training
        races = (try? container.decode(Races.self, forKey: .races)) ?? fallback.races
        products = (try? container.decode(Products.self, forKey: .products)) ?? fallback.products
        records = (try? container.decode(Records.self, forKey: .records)) ?? fallback.records
        partners = (try? container.decode(Partners.self, forKey: .partners)) ?? fallback.partners
    }

    init(
        version: Int,
        home: Home,
        article: Article,
        news: News,
        training: Training,
        races: Races,
        products: Products,
        records: Records,
        partners: Partners
    ) {
        self.version = version
        self.home = home
        self.article = article
        self.news = news
        self.training = training
        self.races = races
        self.products = products
        self.records = records
        self.partners = partners
    }

    static let `default` = ScrapeConfig(
        version: 1,
        home: Home(
            descriptionMeta: #"(?is)<meta\s+name=["']description["']\s+content=["'](.*?)["']"#
        ),
        article: Article(
            articleTag: #"(?is)<article\b[^>]*>(.*?)</article>"#,
            bodyDivMarker: #"(?is)<div\b(?=[^>]*itemprop=["']articleBody["'])[^>]*>"#,
            image: #"(?is)<img\b[^>]*src=["']([^"']+)["']"#
        ),
        news: News(
            articleLink: ##"(?is)<a\s+href="/([^"#?]+)"[^>]*>(.*?)</a>"##,
            image: #"(?is)<img[^>]+src=["']([^"']*/img/500/[^"']+)["']"#,
            title: #"(?is)<strong[^>]*>(.*?)</strong>"#,
            date: #"(?is)<span[^>]*>\s*(\d{2}\.\d{2}\.\d{4})"#
        ),
        training: Training(
            table: #"(?is)<table\b[^>]*class=["'][^"']*training-schedule__info[^"']*["'][^>]*>(.*?)</table>"#,
            row: #"(?is)<tr\b[^>]*>(.*?)</tr>"#,
            cell: #"(?is)<td\b[^>]*>(.*?)</td>"#,
            firstParagraph: #"(?is)<p\b[^>]*>(.*?)</p>"#,
            date: #"(?is)<strong\b[^>]*>(.*?)</strong>"#,
            time: #"(?is)<span\b[^>]*>(.*?)</span>"#,
            removeStrong: #"(?is)<strong\b[^>]*>.*?</strong>"#,
            removeSpan: #"(?is)<span\b[^>]*>.*?</span>"#,
            paragraph: #"(?is)<p\b[^>]*>(.*?)</p>"#
        ),
        races: Races(
            listDivMarker: #"(?is)<div\b(?=[^>]*class=["'][^"']*race-list[^"']*["'])[^>]*>"#,
            link: #"(?is)<a\b[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#,
            titleStrong: #"(?is)<strong\b[^>]*>(.*?)</strong>"#,
            titleHeading: #"(?is)<h[1-6]\b[^>]*>(.*?)</h[1-6]>"#,
            date: #"(?is)<(?:time|span)\b[^>]*>(.*?)</(?:time|span)>"#
        ),
        products: Products(
            link: #"(?is)<a\b[^>]*href=["'](/tovar/[^"']+)["'][^>]*>(.*?)</a>"#,
            image: #"(?is)<img\b[^>]*src=["']([^"']+)["']"#,
            title: #"(?is)<strong\b[^>]*>(.*?)</strong>"#,
            price: #"(?is)<span\b[^>]*>(.*?)</span>"#
        ),
        records: Records(
            tabsList: #"(?is)<ul\b[^>]*class=["'][^"']*tabs__list[^"']*["'][^>]*>(.*?)</ul>"#,
            tabTitle: #"(?is)<span[^>]*>(.*?)</span>"#,
            tabsContentMarker: #"(?is)<div\b(?=[^>]*class=["'][^"']*tabs__content[^"']*["'])[^>]*>"#,
            paragraph: #"(?is)<p\b[^>]*>(.*?)</p>"#
        ),
        partners: Partners(
            listDivMarker: #"(?is)<div\b(?=[^>]*class=["'][^"']*partners__list[^"']*["'])[^>]*>"#,
            link: #"(?is)<a\b[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#,
            image: #"(?is)<img\b[^>]*src=["']([^"']+)["']"#
        )
    )
}

/// Перевіряє, що кожен патерн компілюється й містить щонайменше стільки груп захоплення,
/// скільки з нього читає парсер. Повертає опис першої проблеми або `nil`, якщо конфіг придатний.
/// Ті самі правила для спільного конфіга перевіряє CI у репозиторії rivnerun_api
/// (`.github/scripts/ValidateScrapeConfig.java`): змінюючи поля чи кількість груп, оновіть і його.
extension ScrapeConfig {
    func validationError() -> String? {
        let patterns: [(name: String, pattern: String, requiredGroups: Int)] = [
            ("home.descriptionMeta", home.descriptionMeta, 1),
            ("article.articleTag", article.articleTag, 1),
            ("article.bodyDivMarker", article.bodyDivMarker, 0),
            ("article.image", article.image, 1),
            ("news.articleLink", news.articleLink, 2),
            ("news.image", news.image, 1),
            ("news.title", news.title, 1),
            ("news.date", news.date, 1),
            ("training.table", training.table, 1),
            ("training.row", training.row, 1),
            ("training.cell", training.cell, 1),
            ("training.firstParagraph", training.firstParagraph, 1),
            ("training.date", training.date, 1),
            ("training.time", training.time, 1),
            ("training.removeStrong", training.removeStrong, 0),
            ("training.removeSpan", training.removeSpan, 0),
            ("training.paragraph", training.paragraph, 1),
            ("races.listDivMarker", races.listDivMarker, 0),
            ("races.link", races.link, 2),
            ("races.titleStrong", races.titleStrong, 1),
            ("races.titleHeading", races.titleHeading, 1),
            ("races.date", races.date, 1),
            ("products.link", products.link, 2),
            ("products.image", products.image, 1),
            ("products.title", products.title, 1),
            ("products.price", products.price, 1),
            ("records.tabsList", records.tabsList, 1),
            ("records.tabTitle", records.tabTitle, 1),
            ("records.tabsContentMarker", records.tabsContentMarker, 0),
            ("records.paragraph", records.paragraph, 1),
            ("partners.listDivMarker", partners.listDivMarker, 0),
            ("partners.link", partners.link, 2),
            ("partners.image", partners.image, 1)
        ]
        for (name, pattern, requiredGroups) in patterns {
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern)
            } catch {
                return "\(name): некоректний регулярний вираз (\(error.localizedDescription))"
            }
            if regex.numberOfCaptureGroups < requiredGroups {
                return "\(name): потрібно груп захоплення — \(requiredGroups), знайдено — \(regex.numberOfCaptureGroups)"
            }
        }
        return nil
    }
}

/// Намагається завантажити свіжий конфіг скрейпінгу з мережі; у разі невдачі
/// використовує останній успішно завантажений (кешований), а якщо кешу ще
/// немає — вбудовані значення за замовчуванням. Конфіг, що не проходить
/// `validationError()`, відхиляється ще до кешування.
func resolveScrapeConfig() async -> ScrapeConfig {
    if let remote = await fetchRemoteScrapeConfig() {
        saveCachedScrapeConfig(remote)
        return remote
    }
    return cachedScrapeConfig()
}

/// The config without a network round-trip: last cached, or the built-in default. Use this
/// for one-off parses (e.g. opening a single news article) where re-fetching the shared
/// config on every call would be wasteful — `resolveScrapeConfig()` already keeps it fresh.
func cachedScrapeConfig() -> ScrapeConfig {
    loadCachedScrapeConfig() ?? ScrapeConfig.default
}

private func fetchRemoteScrapeConfig() async -> ScrapeConfig? {
    let config: ScrapeConfig
    do {
        let (data, response) = try await URLSession.shared.data(from: scrapeConfigURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        config = try JSONDecoder().decode(ScrapeConfig.self, from: data)
    } catch {
        return nil
    }
    if let problem = config.validationError() {
        print("Віддалений конфіг скрейпінгу відхилено: \(problem)")
        return nil
    }
    return config
}

private func loadCachedScrapeConfig() -> ScrapeConfig? {
    guard let data = UserDefaults.standard.data(forKey: scrapeConfigCacheKey) else { return nil }
    guard let config = try? JSONDecoder().decode(ScrapeConfig.self, from: data) else { return nil }
    return config.validationError() == nil ? config : nil
}

private func saveCachedScrapeConfig(_ config: ScrapeConfig) {
    guard let data = try? JSONEncoder().encode(config) else { return }
    UserDefaults.standard.set(data, forKey: scrapeConfigCacheKey)
}
