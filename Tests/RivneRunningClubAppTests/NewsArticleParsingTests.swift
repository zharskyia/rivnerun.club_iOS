import XCTest
@testable import RivneRunningClubApp

/// Mirrors Android's `NewsArticleParsingTest.kt` — a hand-built article page covering the
/// gallery markup shape, independent of the larger saved-page fixtures.
final class NewsArticleParsingTests: XCTestCase {
    private let html = """
    <html><body>
    <header><img src="/assets/img/logo-company.svg"></header>
    <article class="article" itemscope itemtype="http://schema.org/Article">
        <h1 itemprop="headline">Андрій Ващук пробіг Берлінський марафон</h1>
        <div class="article__pubdate"><time>28.09.2026, 23:07</time></div>
        <div itemprop="articleBody">
            <img src="/img/1000/20260928_8493.jpg" itemprop="image" loading="lazy">
            <p>Бігун&nbsp;Rivne&nbsp;Running&nbsp;Club пробіг марафон.</p>
            <div class="gallery" id="gallery-lightbox">
                <div class="gallery-lightbox__item" data-src="/img/1000/20260928_8493.jpg">
                    <div class="list-img"><img src="/img/1000/20260928_8493.jpg" loading="lazy"></div>
                </div>
                <div class="gallery-lightbox__item" data-src="/img/1000/20260928_9437.jpg">
                    <div class="list-img"><img src="/img/1000/20260928_9437.jpg" loading="lazy"></div>
                </div>
            </div>
        </div>
    </article>
    <aside><img src="/img/1000/aside.jpg"></aside>
    </body></html>
    """

    func testExtractsOnlyArticleBody() throws {
        let body = try extractArticleBody(html, pageName: "новину", config: .default)
        XCTAssertTrue(body.contains("пробіг марафон"))
        XCTAssertFalse(body.contains("headline"))
        XCTAssertFalse(body.contains("aside.jpg"))
    }

    func testCollectsDistinctAbsolutePhotosFromBody() throws {
        let config = ScrapeConfig.default
        let body = try extractArticleBody(html, pageName: "новину", config: config)
        XCTAssertEqual(
            [
                "https://rivnerun.club/img/1000/20260928_8493.jpg",
                "https://rivnerun.club/img/1000/20260928_9437.jpg"
            ],
            articleImages(body, config: config)
        )
    }
}
