import CryptoKit
import Foundation

private let siteBase = "https://rivnerun.club"
private let newsPageURL = URL(string: "https://rivnerun.club/news")!
private let clubSnapshotFileName = "club_snapshot.json"

struct SiteRefreshResult {
    let snapshot: ClubSnapshot
    let errors: [String]
    let pageCount: Int
}

enum SiteError: Error, LocalizedError {
    case httpStatus(Int, String)
    case parsing(String)

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code, let path):
            return "Сайт клубу повернув HTTP \(code) для \(path)."
        case .parsing(let message):
            return message
        }
    }
}

// MARK: - Fetching

func fetchSiteHTML(_ url: URL) async throws -> String {
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        throw SiteError.httpStatus(code, url.path)
    }
    guard let html = String(data: data, encoding: .utf8) else {
        throw SiteError.parsing("Не вдалося прочитати сторінку \(url.path).")
    }
    return html
}

private struct PageLoad<T> {
    let value: T?
    let error: String?
}

private func loadPage<T>(_ path: String, parser: @escaping (String) throws -> T) async -> PageLoad<T> {
    guard let url = URL(string: siteBase + path) else {
        return PageLoad(value: nil, error: "Некоректний шлях.")
    }
    do {
        let html = try await fetchSiteHTML(url)
        let value = try parser(html)
        return PageLoad(value: value, error: nil)
    } catch {
        return PageLoad(value: nil, error: error.localizedDescription)
    }
}

// MARK: - Snapshot refresh

/// Завантажує всі розділи сайту одночасно й повертає новий знімок, у якому
/// розділи, що не вдалося оновити, залишаються зі значеннями [previous].
func refreshClubSnapshot(previous: ClubSnapshot) async -> SiteRefreshResult {
    let config = await resolveScrapeConfig()

    async let home = loadPage("/") { try parseHomeDescription($0, config: config) }
    async let club = loadPage("/club") { try parseArticleText($0, pageName: "сторінку клубу", config: config) }
    async let news = loadPage("/news") { try parseNewsArchive($0, config: config) }
    async let training = loadPage("/training") { try parseTraining($0, config: config) }
    async let events = loadPage("/events") { try parseRaces($0, config: config) }
    async let shop = loadPage("/shop") { try parseProducts($0, config: config) }
    async let contacts = loadPage("/contacts") { try parseArticleText($0, pageName: "сторінку контактів", config: config) }
    async let donate = loadPage("/donate") { try parseArticleText($0, pageName: "сторінку підтримки", config: config) }
    async let history = loadPage("/istoriya") { try parseArticleText($0, pageName: "історію клубу", config: config) }
    async let founders = loadPage("/zasnovniki") { try parseArticleText($0, pageName: "сторінку засновників", config: config) }
    // /partneri and /rekordi-klubu each feed two parsers (plain text + structured data);
    // fetched once and parsed twice, instead of fetching the same page twice.
    async let partners = loadPage("/partneri") { html in
        (try parseArticleText(html, pageName: "сторінку партнерів", config: config), parsePartners(html, config: config))
    }
    async let records = loadPage("/rekordi-klubu") { html in
        (try parseArticleText(html, pageName: "рекорди клубу", config: config), parseRecords(html, config: config))
    }

    let homeResult = await home
    let clubResult = await club
    let newsResult = await news
    let trainingResult = await training
    let eventsResult = await events
    let shopResult = await shop
    let contactsResult = await contacts
    let donateResult = await donate
    let historyResult = await history
    let foundersResult = await founders
    let partnersResult = await partners
    let recordsResult = await records

    let pageLoads: [(path: String, error: String?)] = [
        ("/", homeResult.error),
        ("/club", clubResult.error),
        ("/news", newsResult.error),
        ("/training", trainingResult.error),
        ("/events", eventsResult.error),
        ("/shop", shopResult.error),
        ("/contacts", contactsResult.error),
        ("/donate", donateResult.error),
        ("/istoriya", historyResult.error),
        ("/zasnovniki", foundersResult.error),
        ("/partneri", partnersResult.error),
        ("/rekordi-klubu", recordsResult.error)
    ]
    let errors = pageLoads.compactMap { entry in entry.error.map { "\(entry.path): \($0)" } }

    var updatedPages = previous.clubPages
    let pageTexts: [(String, String?)] = [
        ("/istoriya", historyResult.value),
        ("/zasnovniki", foundersResult.value),
        ("/partneri", partnersResult.value?.0),
        ("/rekordi-klubu", recordsResult.value?.0)
    ]
    for (path, text) in pageTexts {
        if let text { updatedPages[path] = text }
    }

    var snapshot = previous
    snapshot.homeDescription = homeResult.value ?? previous.homeDescription
    snapshot.clubDescription = clubResult.value ?? previous.clubDescription
    snapshot.news = newsResult.value ?? previous.news
    snapshot.training = trainingResult.value ?? previous.training
    snapshot.races = eventsResult.value ?? previous.races
    snapshot.store = shopResult.value ?? previous.store
    snapshot.contacts = contactsResult.value ?? previous.contacts
    snapshot.support = donateResult.value ?? previous.support
    snapshot.clubPages = updatedPages
    snapshot.records = recordsResult.value?.1 ?? previous.records
    snapshot.partners = partnersResult.value?.1 ?? previous.partners
    if errors.count < pageLoads.count {
        snapshot.lastUpdated = Date()
    }

    return SiteRefreshResult(snapshot: snapshot, errors: errors, pageCount: pageLoads.count)
}

/// Message for the top banner after a refresh: `nil` on full success, a plural-aware count
/// of failed sections on partial failure, or — when every page failed — how stale the data
/// is (or, on the very first launch with no network, that there's nothing to show yet).
func refreshStatusMessage(
    _ result: SiteRefreshResult,
    previous: ClubSnapshot,
    now: Date,
    calendar: Calendar = .current
) -> String? {
    let failed = result.errors.count
    if failed == 0 { return nil }
    if failed < result.pageCount {
        let whereWord = (failed % 10 == 1 && failed % 100 != 11) ? "у ньому" : "у них"
        return "Не вдалося оновити \(failed) \(sectionsWord(failed)) — \(whereWord) показано попередні дані."
    }
    if previous.hasLoadedSiteData, let lastUpdated = previous.lastUpdated {
        return "Немає зв’язку із сайтом клубу. Показано дані, оновлені \(formatUpdateTime(lastUpdated, now: now, calendar: calendar))."
    }
    return "Немає зв’язку із сайтом клубу. Дані з’являться після підключення до Інтернету."
}

private func sectionsWord(_ count: Int) -> String {
    if (11...14).contains(count % 100) { return "розділів" }
    if count % 10 == 1 { return "розділ" }
    if (2...4).contains(count % 10) { return "розділи" }
    return "розділів"
}

func formatUpdateTime(_ updated: Date, now: Date, calendar: Calendar) -> String {
    let time = DateFormatter.rivneRun("HH:mm", calendar: calendar).string(from: updated)
    if calendar.isDate(updated, inSameDayAs: now) {
        return "сьогодні о \(time)"
    }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(updated, inSameDayAs: yesterday) {
        return "учора о \(time)"
    }
    let date = DateFormatter.rivneRun("dd.MM.yyyy", calendar: calendar).string(from: updated)
    return "\(date) о \(time)"
}

private extension DateFormatter {
    static func rivneRun(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.calendar = calendar
        return formatter
    }
}

// MARK: - Cache

/// The snapshot is tens of KB (news, schedule, records…), too large for `UserDefaults`
/// (Apple recommends keeping it to a few KB) — it lives in its own file instead, same as
/// Android's move from SharedPreferences to an `AtomicFile` in `filesDir`.
private func clubSnapshotFile() -> URL? {
    guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        return nil
    }
    return dir.appendingPathComponent(clubSnapshotFileName)
}

func loadCachedClubSnapshot() -> ClubSnapshot? {
    guard let file = clubSnapshotFile(), let data = try? Data(contentsOf: file) else { return nil }
    return try? JSONDecoder().decode(ClubSnapshot.self, from: data)
}

/// Best-effort save: if it fails, the data is simply fetched from the site again next time.
func saveCachedClubSnapshot(_ snapshot: ClubSnapshot) {
    guard let file = clubSnapshotFile(), let data = try? JSONEncoder().encode(snapshot) else { return }
    try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: file, options: .atomic)
}

// MARK: - News article fetch + cache

/// Boxes a value type for `NSCache`, which only holds class instances.
private final class NewsArticleBox {
    let content: NewsArticleContent
    init(_ content: NewsArticleContent) { self.content = content }
}

private let newsArticleMemoryCache: NSCache<NSString, NewsArticleBox> = {
    let cache = NSCache<NSString, NewsArticleBox>()
    cache.countLimit = 20
    return cache
}()

func memoryCachedNewsArticle(_ articleUrl: String) -> NewsArticleContent? {
    newsArticleMemoryCache.object(forKey: articleUrl as NSString)?.content
}

private func cacheNewsArticleInMemory(_ content: NewsArticleContent, for articleUrl: String) {
    newsArticleMemoryCache.setObject(NewsArticleBox(content), forKey: articleUrl as NSString)
}

private func newsArticleCacheFile(for articleUrl: String) -> URL? {
    guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
        return nil
    }
    let digest = SHA256.hash(data: Data(articleUrl.utf8))
    let name = digest.map { String(format: "%02x", $0) }.joined()
    return cachesDir.appendingPathComponent("news_articles", isDirectory: true).appendingPathComponent("\(name).json")
}

func diskCachedNewsArticle(_ articleUrl: String) -> NewsArticleContent? {
    guard let file = newsArticleCacheFile(for: articleUrl), let data = try? Data(contentsOf: file) else { return nil }
    return try? JSONDecoder().decode(NewsArticleContent.self, from: data)
}

private func saveNewsArticleToDisk(_ content: NewsArticleContent, for articleUrl: String) {
    guard let file = newsArticleCacheFile(for: articleUrl), let data = try? JSONEncoder().encode(content) else { return }
    try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: file, options: .atomic)
}

/// Fetches a news article's full text and photo gallery from its own page, and caches it
/// in memory and on disk. Call sites should show `memoryCachedNewsArticle`/`diskCachedNewsArticle`
/// immediately if present, then call this to refresh — mirrors Android's `newsArticleFlow`.
func fetchAndCacheNewsArticle(_ articleUrl: String) async throws -> NewsArticleContent {
    guard let url = URL(string: articleUrl) else {
        throw SiteError.parsing("Некоректна адреса новини.")
    }
    let config = cachedScrapeConfig()
    let html = try await fetchSiteHTML(url)
    let content = try parseNewsArticle(html, config: config)
    cacheNewsArticleInMemory(content, for: articleUrl)
    saveNewsArticleToDisk(content, for: articleUrl)
    return content
}

// MARK: - Parsers

// Parsers below are `internal` (not `private`) so the test target can exercise them
// directly against saved HTML fixtures instead of only through a live network fetch.
func parseHomeDescription(_ html: String, config: ScrapeConfig) throws -> String {
    guard let raw = find(config.home.descriptionMeta, in: html)?.groups[safe: 1] else {
        throw SiteError.parsing("Опис головної сторінки не знайдено.")
    }
    let description = plainText(raw)
    guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw SiteError.parsing("Опис головної сторінки не знайдено.")
    }
    return description
}

/// The article body HTML: the `itemprop="articleBody"` block if present, otherwise the
/// whole `<article>`. Shared by plain pages and news articles (which also need its images).
func extractArticleBody(_ html: String, pageName: String, config: ScrapeConfig) throws -> String {
    guard let article = find(config.article.articleTag, in: html)?.groups[safe: 1] else {
        throw SiteError.parsing("Не знайдено вмісту для \(pageName).")
    }
    if let bodyStart = find(config.article.bodyDivMarker, in: article),
       let contents = extractDivContents(article, openingTagRange: bodyStart.range) {
        return contents
    }
    return article
}

private func articleText(_ body: String, pageName: String) throws -> String {
    let text = plainText(body)
    if text.contains("Вітаємо Вас із успішною реєстрацією на забіг") {
        throw SiteError.parsing("Сторінка \(pageName) не повернула очікуваний вміст.")
    }
    return text
}

func parseArticleText(_ html: String, pageName: String, config: ScrapeConfig) throws -> String {
    try articleText(extractArticleBody(html, pageName: pageName, config: config), pageName: pageName)
}

func parseNewsArticle(_ html: String, config: ScrapeConfig) throws -> NewsArticleContent {
    let body = try extractArticleBody(html, pageName: "новину", config: config)
    return NewsArticleContent(
        text: try articleText(body, pageName: "новину"),
        imageUrls: articleImages(body, config: config)
    )
}

func articleImages(_ bodyHtml: String, config: ScrapeConfig) -> [String] {
    var seen = Set<String>()
    var urls: [String] = []
    for match in findAll(config.article.image, in: bodyHtml) {
        guard let rawPath = match.groups[safe: 1] else { continue }
        let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, !path.lowercased().hasPrefix("data:") else { continue }
        let url = absoluteURL(path)
        if seen.insert(url).inserted { urls.append(url) }
    }
    return urls
}

func parseTraining(_ html: String, config: ScrapeConfig) throws -> [TrainingSession] {
    guard let table = find(config.training.table, in: html)?.groups[safe: 1] else {
        throw SiteError.parsing("Не знайдено розклад тренувань.")
    }

    var sessions: [TrainingSession] = []
    for row in findAll(config.training.row, in: table) {
        guard let rowHtml = row.groups[safe: 1] else { continue }
        let cells = findAll(config.training.cell, in: rowHtml).compactMap { $0.groups[safe: 1] }
        guard cells.count >= 2 else { continue }

        let firstCell = cells[0]
        let secondCell = cells[1]
        let firstParagraph = find(config.training.firstParagraph, in: firstCell)?.groups[safe: 1] ?? firstCell
        let date = find(config.training.date, in: firstParagraph)?.groups[safe: 1].map(plainText) ?? ""
        let time = find(config.training.time, in: firstParagraph)?.groups[safe: 1].map(plainText) ?? ""
        let withoutStrong = replaceAll(config.training.removeStrong, in: firstParagraph, with: " ")
        let withoutSpan = replaceAll(config.training.removeSpan, in: withoutStrong, with: " ")
        let day = plainText(withoutSpan)

        let paragraphs = findAll(config.training.paragraph, in: secondCell)
            .compactMap { $0.groups[safe: 1].map(plainText) }
            .filter { !$0.isEmpty }
        guard let title = paragraphs.first else { continue }
        let location = paragraphs[safe: 1] ?? ""
        let description = paragraphs.count > 2 ? paragraphs[2...].joined(separator: "\n") : ""

        if day.isEmpty || date.isEmpty || time.isEmpty { continue }
        sessions.append(TrainingSession(day: day, date: date, time: time, title: title, location: location, description: description))
    }

    if sessions.isEmpty, find(#"(?is)<tr\b"#, in: table) != nil {
        throw SiteError.parsing("Не вдалося розібрати розклад тренувань.")
    }
    return sessions
}

func parseRaces(_ html: String, config: ScrapeConfig) throws -> [RaceItem] {
    guard let raceListStart = find(config.races.listDivMarker, in: html) else {
        throw SiteError.parsing("Не знайдено список забігів.")
    }
    guard let raceList = extractDivContents(html, openingTagRange: raceListStart.range) else {
        throw SiteError.parsing("Не знайдено список забігів.")
    }

    var races: [RaceItem] = []
    var seenIds = Set<Int>()
    for match in findAll(config.races.link, in: raceList) {
        guard let href = match.groups[safe: 1], let body = match.groups[safe: 2] else { continue }
        let title: String
        if let strong = find(config.races.titleStrong, in: body)?.groups[safe: 1] {
            title = plainText(strong)
        } else if let heading = find(config.races.titleHeading, in: body)?.groups[safe: 1] {
            title = plainText(heading)
        } else {
            continue
        }
        let date = find(config.races.date, in: body)?.groups[safe: 1].map(plainText) ?? ""
        let description = plainText(body)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0 != title && $0 != date }
            .joined(separator: "\n")
        let id = stableHash(href)
        guard seenIds.insert(id).inserted else { continue }
        races.append(RaceItem(id: id, title: title, date: date, description: description, url: resolveSiteLink(href)))
    }
    return races
}

func parseProducts(_ html: String, config: ScrapeConfig) throws -> [StoreItem] {
    var seen = Set<String>()
    var products: [StoreItem] = []
    for match in findAll(config.products.link, in: html) {
        guard let href = match.groups[safe: 1], let body = match.groups[safe: 2] else { continue }
        guard let imagePath = find(config.products.image, in: body)?.groups[safe: 1] else { continue }
        guard let titleRaw = find(config.products.title, in: body)?.groups[safe: 1] else { continue }
        let title = plainText(titleRaw)
        let price = find(config.products.price, in: body)?.groups[safe: 1].map(plainText) ?? ""
        let productUrl = absoluteURL(href)
        guard seen.insert(productUrl).inserted else { continue }
        products.append(StoreItem(title: title, price: price, imageURL: absoluteURL(imagePath), productUrl: productUrl))
    }
    if products.isEmpty {
        throw SiteError.parsing("Не вдалося прочитати каталог товарів.")
    }
    return products
}

func parseRecords(_ html: String, config: ScrapeConfig) -> [RecordsTab] {
    guard let tabsListHtml = find(config.records.tabsList, in: html)?.groups[safe: 1] else { return [] }
    let titles = findAll(config.records.tabTitle, in: tabsListHtml)
        .compactMap { $0.groups[safe: 1].map(plainText) }
    guard let contentMarker = find(config.records.tabsContentMarker, in: html) else { return [] }
    guard let contentHtml = extractDivContents(html, openingTagRange: contentMarker.range) else { return [] }
    let tabBodies = splitTopLevelDivs(contentHtml)

    var tabs: [RecordsTab] = []
    for (index, title) in titles.enumerated() {
        guard index < tabBodies.count else { continue }
        let body = tabBodies[index]
        let paragraphs = findAll(config.records.paragraph, in: body)
            .compactMap { $0.groups[safe: 1].map(plainText) }

        var groups: [RecordGroup] = []
        var heading: String? = nil
        var records: [String] = []
        var awaitingHeading = true
        for paragraph in paragraphs {
            if paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                awaitingHeading = true
                continue
            }
            if awaitingHeading {
                if let previousHeading = heading, !records.isEmpty {
                    groups.append(RecordGroup(heading: previousHeading, records: records))
                }
                heading = paragraph
                records = []
                awaitingHeading = false
            } else {
                records.append(paragraph)
            }
        }
        if let heading, !records.isEmpty {
            groups.append(RecordGroup(heading: heading, records: records))
        }
        tabs.append(RecordsTab(title: title, groups: groups))
    }
    return tabs
}

func parsePartners(_ html: String, config: ScrapeConfig) -> [PartnerItem] {
    guard let listStart = find(config.partners.listDivMarker, in: html) else { return [] }
    guard let listHtml = extractDivContents(html, openingTagRange: listStart.range) else { return [] }
    var partners: [PartnerItem] = []
    for match in findAll(config.partners.link, in: listHtml) {
        guard let href = match.groups[safe: 1], let linkBody = match.groups[safe: 2] else { continue }
        guard let imagePath = find(config.partners.image, in: linkBody)?.groups[safe: 1] else { continue }
        partners.append(PartnerItem(logoUrl: absoluteURL(imagePath), websiteUrl: resolveSiteLink(href)))
    }
    return partners
}

func parseNewsArchive(_ html: String, config: ScrapeConfig) throws -> [NewsItem] {
    var uniqueArticles: [String: NewsItem] = [:]
    var order: [String] = []

    for match in findAll(config.news.articleLink, in: html) {
        guard let href = match.groups[safe: 1], let articleHtml = match.groups[safe: 2] else { continue }
        guard let imagePath = find(config.news.image, in: articleHtml)?.groups[safe: 1] else { continue }
        guard let rawTitle = find(config.news.title, in: articleHtml)?.groups[safe: 1] else { continue }
        guard let date = find(config.news.date, in: articleHtml)?.groups[safe: 1] else { continue }

        let title = plainText(rawTitle)
        guard !title.isEmpty,
              let articleUrl = URL(string: "/\(href)", relativeTo: newsPageURL),
              let imageUrl = URL(string: imagePath, relativeTo: newsPageURL) else { continue }

        let key = articleUrl.absoluteURL.absoluteString
        if uniqueArticles[key] == nil {
            // No real excerpt on the archive page — `excerpt` hides this until the article itself loads.
            uniqueArticles[key] = NewsItem(title: title, date: date, imageURL: imageUrl.absoluteURL.absoluteString, summary: "", articleUrl: key)
            order.append(key)
        }
    }

    if uniqueArticles.isEmpty {
        throw SiteError.parsing("Не вдалося розібрати список новин із сайту клубу.")
    }

    return order.compactMap { uniqueArticles[$0] }
}

// MARK: - HTML helpers

/// Unlike Kotlin's `List.getOrNull`, a plain Swift array subscript out of range is a
/// `fatalError` that crashes the whole app, not a catchable error — a single missing
/// `count >` guard around `match.groups[n]` would take down the process instead of just
/// degrading one page. This makes that structurally impossible at the call site.
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Mirrors Kotlin's `Regex.find(input).groupValues` — group 0 is the whole match,
/// non-participating groups come back as "".
private func find(_ pattern: String, in text: String) -> (range: NSRange, groups: [String])? {
    guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
    let ns = text as NSString
    guard let result = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
    var groups: [String] = []
    for i in 0..<result.numberOfRanges {
        let r = result.range(at: i)
        groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
    }
    return (result.range, groups)
}

/// Mirrors Kotlin's `Regex.findAll(input)` — all non-overlapping matches, each with groupValues.
private func findAll(_ pattern: String, in text: String) -> [(range: NSRange, groups: [String])] {
    guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
    let ns = text as NSString
    let results = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
    return results.map { result in
        var groups: [String] = []
        for i in 0..<result.numberOfRanges {
            let r = result.range(at: i)
            groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
        }
        return (result.range, groups)
    }
}

private func replaceAll(_ pattern: String, in text: String, with replacement: String) -> String {
    guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
    let range = NSRange(location: 0, length: (text as NSString).length)
    return re.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
}

/// Returns (start, end) UTF-16 offsets of the `</div>` that balances the
/// opening tag at [openingTagRange], scanning only forward from it.
private func findMatchingDivEnd(_ html: String, openingTagRange: NSRange) -> (start: Int, end: Int)? {
    guard let re = try? NSRegularExpression(pattern: #"(?is)</?div\b[^>]*>"#) else { return nil }
    let ns = html as NSString
    let searchStart = openingTagRange.location + openingTagRange.length
    guard searchStart <= ns.length else { return nil }
    let searchRange = NSRange(location: searchStart, length: ns.length - searchStart)

    var depth = 1
    var found: (start: Int, end: Int)?
    re.enumerateMatches(in: html, range: searchRange) { result, _, stop in
        guard let result else { return }
        let value = ns.substring(with: result.range)
        if value.lowercased().hasPrefix("</") {
            depth -= 1
        } else if !value.hasSuffix("/>") {
            depth += 1
        }
        if depth == 0 {
            found = (result.range.location, result.range.location + result.range.length)
            stop.pointee = true
        }
    }
    return found
}

private func extractDivContents(_ html: String, openingTagRange: NSRange) -> String? {
    guard let end = findMatchingDivEnd(html, openingTagRange: openingTagRange) else { return nil }
    let ns = html as NSString
    let start = openingTagRange.location + openingTagRange.length
    guard end.start >= start else { return nil }
    return ns.substring(with: NSRange(location: start, length: end.start - start))
}

/// Splits the direct `<div>` children of [html] into their inner contents, depth-balanced.
private func splitTopLevelDivs(_ html: String) -> [String] {
    guard let re = try? NSRegularExpression(pattern: #"(?is)<div\b[^>]*>"#) else { return [] }
    let ns = html as NSString
    var result: [String] = []
    var searchFrom = 0
    while searchFrom <= ns.length {
        let searchRange = NSRange(location: searchFrom, length: ns.length - searchFrom)
        guard let openMatch = re.firstMatch(in: html, range: searchRange) else { break }
        guard let end = findMatchingDivEnd(html, openingTagRange: openMatch.range) else { break }
        let start = openMatch.range.location + openMatch.range.length
        if end.start >= start {
            result.append(ns.substring(with: NSRange(location: start, length: end.start - start)))
        }
        searchFrom = end.end
    }
    return result
}

private let scriptOrStylePattern = #"(?is)<(script|style)\b.*?</\1\s*>"#
private let whitespaceRunPattern = #"\s+"#
private let lineBreakTagPattern = #"(?i)<br\s*/?>"#
private let blockTagPattern = #"(?i)</?(?:p|div|li|ul|ol|tr|table|h[1-6]|blockquote|section|article)\b[^>]*>"#
private let cellEndTagPattern = #"(?i)</t[dh]\s*>"#
private let anyTagPattern = #"(?s)<[^>]*>"#
private let spaceRunPattern = #"[ \t]+"#

/// Text of an HTML fragment the way a browser would show it: whitespace collapses, `<br>`
/// and block-element boundaries become line breaks, empty lines are dropped. Mirrors
/// Android's `HtmlText.kt` (which replaced relying on `android.text.Html`).
func plainText(_ html: String) -> String {
    var text = html
    text = replaceAll(scriptOrStylePattern, in: text, with: " ")
    text = replaceAll(whitespaceRunPattern, in: text, with: " ")
    text = replaceAll(lineBreakTagPattern, in: text, with: "\n")
    text = replaceAll(blockTagPattern, in: text, with: "\n")
    text = replaceAll(cellEndTagPattern, in: text, with: " ")
    text = replaceAll(anyTagPattern, in: text, with: "")
    text = decodeHTMLEntities(text)
    text = text.replacingOccurrences(of: "\u{00a0}", with: " ")
    // Invisible characters left by the site's editor (e.g. a zero-width space after an
    // email address) shouldn't end up in the displayed text.
    text.removeAll { $0 == "\u{200B}" || $0 == "\u{FEFF}" || $0 == "\u{FFFC}" }
    let lines = text
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { replaceAll(spaceRunPattern, in: String($0), with: " ").trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    return lines.joined(separator: "\n")
}

private let namedHTMLEntities: [String: String] = [
    "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
    "nbsp": "\u{00A0}", "ensp": "\u{2002}", "emsp": "\u{2003}", "thinsp": "\u{2009}",
    "shy": "\u{00AD}", "zwnj": "\u{200C}", "zwj": "\u{200D}",
    "laquo": "«", "raquo": "»", "lsquo": "‘", "rsquo": "’", "sbquo": "‚",
    "ldquo": "“", "rdquo": "”", "bdquo": "„", "prime": "′", "Prime": "″",
    "ndash": "–", "mdash": "—", "minus": "−", "hellip": "…", "middot": "·", "bull": "•",
    "copy": "©", "reg": "®", "trade": "™", "deg": "°", "plusmn": "±",
    "times": "×", "divide": "÷", "frac12": "½", "frac14": "¼", "frac34": "¾",
    "sup1": "¹", "sup2": "²", "sup3": "³", "micro": "µ", "para": "¶", "sect": "§",
    "euro": "€", "pound": "£", "cent": "¢", "yen": "¥", "curren": "¤",
    "iexcl": "¡", "iquest": "¿", "acute": "´", "uml": "¨", "cedil": "¸", "macr": "¯",
    "larr": "←", "rarr": "→", "uarr": "↑", "darr": "↓", "harr": "↔"
]

private let entityPattern = #"&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);"#

private func decodeHTMLEntities(_ text: String) -> String {
    guard text.contains("&") else { return text }
    guard let re = try? NSRegularExpression(pattern: entityPattern) else { return text }
    let ns = text as NSString
    let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
    guard !matches.isEmpty else { return text }

    var output = ""
    var lastEnd = 0
    for match in matches {
        output += ns.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
        let whole = ns.substring(with: match.range)
        let name = ns.substring(with: match.range(at: 1))
        let decoded: String?
        if name.lowercased().hasPrefix("#x") {
            decoded = UInt32(name.dropFirst(2), radix: 16).flatMap(codePointText)
        } else if name.hasPrefix("#") {
            decoded = UInt32(name.dropFirst(1)).flatMap(codePointText)
        } else {
            decoded = namedHTMLEntities[name]
        }
        output += decoded ?? whole
        lastEnd = match.range.location + match.range.length
    }
    output += ns.substring(from: lastEnd)
    return output
}

private func codePointText(_ codePoint: UInt32) -> String? {
    guard codePoint > 0, let scalar = Unicode.Scalar(codePoint) else { return nil }
    return String(Character(scalar))
}

/// A stable (cross-launch, cross-platform-shaped) string hash, unlike Swift's
/// randomized `String.hashValue` — used for `RaceItem.id` so the same race keeps
/// the same id across refreshes instead of reshuffling every launch.
private func stableHash(_ string: String) -> Int {
    var hash: UInt64 = 5381
    for byte in string.utf8 {
        hash = hash &* 33 &+ UInt64(byte)
    }
    return Int(truncatingIfNeeded: hash)
}

private func absoluteURL(_ path: String) -> String {
    if path.hasPrefix("http://") || path.hasPrefix("https://") { return path }
    let trimmed = path.drop(while: { $0 == "/" })
    return "\(siteBase)/\(trimmed)".replacingOccurrences(of: " ", with: "%20")
}

/// Resolves an `href` from the site's HTML against the site root; returns it unchanged
/// if it isn't a usable URL (e.g. a bare anchor or malformed link).
private func resolveSiteLink(_ href: String) -> String {
    let cleaned = href.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: " ", with: "%20")
    guard let base = URL(string: "\(siteBase)/"), let resolved = URL(string: cleaned, relativeTo: base) else {
        return href
    }
    return resolved.absoluteURL.absoluteString
}
