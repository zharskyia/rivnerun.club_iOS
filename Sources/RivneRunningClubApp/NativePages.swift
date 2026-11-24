import Foundation
import SwiftUI

// MARK: - Live snapshot environment

private struct ClubSnapshotKey: EnvironmentKey {
    static let defaultValue = ClubSnapshot.bundled
}

extension EnvironmentValues {
    /// The latest scraped-or-cached snapshot of rivnerun.club. See `ClubSiteRepository.swift`.
    var clubSnapshot: ClubSnapshot {
        get { self[ClubSnapshotKey.self] }
        set { self[ClubSnapshotKey.self] = newValue }
    }
}

private struct RefreshSnapshotKey: EnvironmentKey {
    static let defaultValue: () async -> Void = {}
}

extension EnvironmentValues {
    /// Pull-to-refresh on any tab root or list calls this to re-fetch the site, same action
    /// as the retry button on the top error banner — both go through `ContentView`'s single
    /// in-flight refresh.
    var refreshSnapshot: () async -> Void {
        get { self[RefreshSnapshotKey.self] }
        set { self[RefreshSnapshotKey.self] = newValue }
    }
}

// MARK: - Push navigation

enum NativeDestination: Hashable {
    case newsArchive
    case newsArticle(NewsItem)
    case store
    case product(StoreItem)
    case clubInfo(title: String, description: String)
    case records
    case partners
}

@ViewBuilder
func nativeDestinationView(for destination: NativeDestination, path: Binding<[NativeDestination]>) -> some View {
    switch destination {
    case .newsArchive:
        NewsArchiveContainer(path: path)
    case .newsArticle(let item):
        NewsArticleDetailView(item: item)
    case .store:
        StoreListContainer(path: path)
    case .product(let item):
        ProductDetailView(item: item)
    case .clubInfo(let title, let description):
        ClubInfoView(title: title, description: description)
    case .records:
        RecordsContainer()
    case .partners:
        PartnersContainer()
    }
}

private struct NewsArchiveContainer: View {
    @Environment(\.clubSnapshot) private var snapshot
    var path: Binding<[NativeDestination]>
    var body: some View { NewsArchiveView(news: snapshot.news, path: path) }
}

private struct StoreListContainer: View {
    @Environment(\.clubSnapshot) private var snapshot
    var path: Binding<[NativeDestination]>
    var body: some View { StoreListView(items: snapshot.store, path: path) }
}

private struct RecordsContainer: View {
    @Environment(\.clubSnapshot) private var snapshot
    var body: some View { RecordsView(tabs: snapshot.records) }
}

private struct PartnersContainer: View {
    @Environment(\.clubSnapshot) private var snapshot
    var body: some View { PartnersView(description: snapshot.clubPages["/partneri"] ?? "", partners: snapshot.partners) }
}

// MARK: - Mail drafts

/// Builds a `mailto:` URL analogous to Android's `ACTION_SENDTO` intent — opens
/// the device's mail app with a prefilled draft instead of sending anything directly.
/// Empty parameters are left out entirely, matching Android's `mailtoUri`: some mail
/// clients render a literal empty `body=` rather than treating it as blank.
func mailDraftURL(subject: String, body: String) -> URL? {
    let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+"))
    let parts: [(name: String, value: String)] = [("subject", subject), ("body", body)]
    let query = parts
        .filter { !$0.value.isEmpty }
        .compactMap { part -> String? in
            guard let encoded = part.value.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
            return "\(part.name)=\(encoded)"
        }
        .joined(separator: "&")
    let suffix = query.isEmpty ? "" : "?\(query)"
    return URL(string: "mailto:rivnerun@gmail.com\(suffix)")
}

func isValidEmail(_ email: String) -> Bool {
    email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
}

// MARK: - Shared widgets

struct NativeCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: AppTheme.shadow, radius: 3, x: 0, y: 4)
    }
}

struct SocialLinksFooter: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(contactLinks) { link in
                Spacer(minLength: 0)
                Link(destination: URL(string: link.url) ?? URL(string: "https://rivnerun.club")!) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: link.tint) ?? AppTheme.black)
                            .frame(width: 40, height: 40)
                        Image(systemName: link.icon)
                            .foregroundStyle(AppTheme.white)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(link.name)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// A checkbox with a clearly visible square outline (Android backlog: "обведи чіткими
/// контурами межі чекбоксів щоб їх було добре видно").
struct BorderedCheckbox: View {
    let text: String
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isChecked ? AppTheme.green : AppTheme.white)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppTheme.black, lineWidth: 1.5)
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.white)
                    }
                }
                .frame(width: 22, height: 22)

                Text(text)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.black)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }
}

/// An async image that opens a fullscreen dark viewer on tap (Android backlog:
/// "усі фото в новинах мають бути клікабельними (збільшуватись при натисканні)").
struct ZoomableAsyncImage: View {
    let url: String
    var contentMode: ContentMode = .fill
    /// The full-resolution version to show when zoomed, if different from the thumbnail `url`.
    var zoomedURL: String?

    @State private var isZoomed = false

    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(AppTheme.yellow.opacity(0.5))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isZoomed = true }
        .fullScreenCover(isPresented: $isZoomed) {
            ZStack {
                Color.black.opacity(0.94).ignoresSafeArea()
                AsyncImage(url: URL(string: zoomedURL ?? url)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().padding(12)
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                VStack {
                    Spacer()
                    Text("Натисніть, щоб закрити")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 28)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isZoomed = false }
        }
    }
}

// MARK: - News

struct NewsArchiveView: View {
    let news: [NewsItem]
    @Binding var path: [NativeDestination]
    @Environment(\.refreshSnapshot) private var refreshSnapshot

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(news) { item in
                    HStack(spacing: 12) {
                        ZoomableAsyncImage(url: item.imageURL)
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title).font(.headline).foregroundStyle(AppTheme.black)
                                Text(item.date).font(.caption).foregroundStyle(AppTheme.muted)
                                if let excerpt = item.excerpt {
                                    Text(excerpt).font(.caption).foregroundStyle(AppTheme.muted).lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { path.append(.newsArticle(item)) }
                    }
                    .padding(12)
                    .background(AppTheme.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: AppTheme.shadow, radius: 3, x: 0, y: 4)
                }
            }
            .padding(16)
        }
        .refreshable { await refreshSnapshot() }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Новини")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum NewsArticleState {
    case loading
    case loaded(NewsArticleContent)
    case failed
}

struct NewsArticleDetailView: View {
    let item: NewsItem
    @Environment(\.openURL) private var openURL

    @State private var state: NewsArticleState
    @State private var attempt = 0

    init(item: NewsItem) {
        self.item = item
        let cached = memoryCachedNewsArticle(item.articleUrl) ?? diskCachedNewsArticle(item.articleUrl)
        _state = State(initialValue: cached.map(NewsArticleState.loaded) ?? .loading)
    }

    // У списку новина має зменшене фото (/img/500/), а в статті те саме фото є в повному розмірі.
    private var articlePhotos: [String] {
        if case .loaded(let content) = state { return content.imageUrls }
        return []
    }
    private var mainPhotoName: String { (item.imageURL as NSString).lastPathComponent }
    private var mainPhotoFullSize: String {
        articlePhotos.first { ($0 as NSString).lastPathComponent == mainPhotoName } ?? item.imageURL
    }
    private var gallery: [String] {
        articlePhotos.filter { ($0 as NSString).lastPathComponent != mainPhotoName }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ZoomableAsyncImage(url: item.imageURL, contentMode: .fill, zoomedURL: mainPhotoFullSize)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .background(AppTheme.yellow)
                    .id(attempt)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.date).font(.subheadline.bold()).foregroundStyle(AppTheme.green)
                    Text(item.title).font(.title3.bold()).foregroundStyle(AppTheme.black)
                }

                switch state {
                case .loading:
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Завантажуємо новину…").foregroundStyle(AppTheme.muted)
                    }
                case .loaded(let content):
                    if !content.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        NativeCard {
                            Text(content.text).foregroundStyle(AppTheme.black)
                        }
                    }
                case .failed:
                    NativeCard {
                        Text("Не вдалося завантажити текст новини. Перевірте підключення до Інтернету.")
                            .foregroundStyle(AppTheme.black)
                        Button("Спробувати ще раз") { attempt += 1 }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.green)
                            .fontWeight(.semibold)
                    }
                }

                if !gallery.isEmpty {
                    GalleryGrid(urls: gallery)
                }

                Button("Відкрити на сайті") {
                    if let url = URL(string: item.articleUrl) { openURL(url) }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.green)
                .fontWeight(.semibold)
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Новина")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: attempt) {
            await loadArticle()
        }
    }

    private func loadArticle() async {
        if let cached = memoryCachedNewsArticle(item.articleUrl) {
            state = .loaded(cached)
            return
        }
        if case .failed = state {
            state = .loading
        }
        do {
            let fresh = try await fetchAndCacheNewsArticle(item.articleUrl)
            state = .loaded(fresh)
        } catch {
            if case .loaded = state { return }
            state = .failed
        }
    }
}

private struct GalleryGrid: View {
    let urls: [String]

    private var rows: [[String]] {
        stride(from: 0, to: urls.count, by: 2).map { Array(urls[$0..<min($0 + 2, urls.count)]) }
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { url in
                        ZoomableAsyncImage(url: url, contentMode: .fill)
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    if row.count == 1 {
                        Color.clear.aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Store

struct StoreListView: View {
    let items: [StoreItem]
    @Binding var path: [NativeDestination]
    @Environment(\.refreshSnapshot) private var refreshSnapshot

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: item.imageURL)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Rectangle().fill(AppTheme.softGreen)
                            }
                        }
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title).fontWeight(.bold).foregroundStyle(AppTheme.black)
                            Text(item.price).fontWeight(.bold).foregroundStyle(AppTheme.green)
                            Text("Переглянути товар").font(.caption).foregroundStyle(AppTheme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(AppTheme.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: AppTheme.shadow, radius: 3, x: 0, y: 4)
                    .contentShape(Rectangle())
                    .onTapGesture { path.append(.product(item)) }
                }
            }
            .padding(16)
        }
        .refreshable { await refreshSnapshot() }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Магазин")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProductDetailView: View {
    let item: StoreItem
    @Environment(\.openURL) private var openURL

    @State private var name = ""
    @State private var phone = ""
    @State private var size = ""
    @State private var showValidation = false

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !phone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                NativeCard {
                    ZoomableAsyncImage(url: item.imageURL)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    Text(item.title).font(.title3.bold()).foregroundStyle(AppTheme.black)
                    Text(item.price).font(.headline).foregroundStyle(AppTheme.green)
                    Text("Для замовлення залиште контактні дані. Застосунок відкриє чернетку листа.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                }
                NativeCard {
                    Text("Замовлення").font(.headline).foregroundStyle(AppTheme.black)
                    TextField("Ім'я", text: $name)
                        .textFieldStyle(.roundedBorder)
                    TextField("Номер телефону", text: $phone)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.phonePad)
                    TextField("Розмір / побажання", text: $size)
                        .textFieldStyle(.roundedBorder)
                    if showValidation && !canSubmit {
                        Text("Вкажіть ім’я та номер телефону.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button {
                        showValidation = true
                        guard canSubmit else { return }
                        let body = "Товар: \(item.title) (\(item.price))\nІм'я: \(name)\nТелефон: \(phone)\nРозмір / побажання: \(size)"
                        if let url = mailDraftURL(subject: "Замовлення: \(item.title)", body: body) {
                            openURL(url)
                        }
                    } label: {
                        Text("Замовити")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.green)
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Товар")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Join the club

struct JoinFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthDate: Date?
    @State private var shirtSize = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var gender = ""
    @State private var mailingAddress = ""
    @State private var healthConsent = false
    @State private var privacyConsent = false
    @State private var showValidation = false

    private let shirtSizes = ["XXS", "XS", "SM", "M", "L", "XL", "XXL"]
    private let genders = ["Чоловік", "Жінка"]

    private var emailIsValid: Bool { isValidEmail(email) }
    private var allRequiredFieldsValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
            birthDate != nil &&
            !shirtSize.isEmpty &&
            !phone.trimmingCharacters(in: .whitespaces).isEmpty &&
            emailIsValid &&
            !gender.isEmpty
    }
    private var consentsGranted: Bool { healthConsent && privacyConsent }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Заповніть усі обов’язкові поля та підтвердіть обидві згоди.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)

                    TextField("Ім'я *", text: $firstName)
                    TextField("Прізвище *", text: $lastName)

                    DatePicker(
                        "Дата народження *",
                        selection: Binding(get: { birthDate ?? Date() }, set: { birthDate = $0 }),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    if showValidation && birthDate == nil {
                        Text("Оберіть дату народження.").font(.caption).foregroundStyle(.red)
                    }

                    Picker("Розмір футболки *", selection: $shirtSize) {
                        Text("Оберіть").tag("")
                        ForEach(shirtSizes, id: \.self) { size in Text(size).tag(size) }
                    }

                    TextField("Телефон *", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email *", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    if showValidation && !email.isEmpty && !emailIsValid {
                        Text("Введіть коректну адресу email.").font(.caption).foregroundStyle(.red)
                    }

                    Picker("Стать *", selection: $gender) {
                        Text("Оберіть").tag("")
                        ForEach(genders, id: \.self) { value in Text(value).tag(value) }
                    }

                    TextField("Адреса для листування", text: $mailingAddress)
                }

                Section {
                    BorderedCheckbox(
                        text: "Підтверджую, що маю добрий стан здоров’я, і можу брати участь у тренуваннях під власну відповідальність.",
                        isChecked: $healthConsent
                    )
                    BorderedCheckbox(
                        text: "Даю дозвіл на обробку персональних даних",
                        isChecked: $privacyConsent
                    )
                    if showValidation && !allRequiredFieldsValid {
                        Text("Заповніть усі обов’язкові поля коректно.").font(.caption).foregroundStyle(.red)
                    }
                    if showValidation && !consentsGranted {
                        Text("Для подання заявки потрібно підтвердити обидві згоди.").font(.caption).foregroundStyle(.red)
                    }
                }

                Button {
                    showValidation = true
                    guard allRequiredFieldsValid && consentsGranted else { return }
                    let birthDateText = birthDate.map { Self.dateFormatter.string(from: $0) } ?? ""
                    let body = """
                    Ім'я: \(firstName)
                    Прізвище: \(lastName)
                    Дата народження: \(birthDateText)
                    Розмір футболки: \(shirtSize)
                    Телефон: \(phone)
                    Email: \(email)
                    Стать: \(gender)
                    Адреса для листування: \(mailingAddress)
                    Підтверджую добрий стан здоров’я та участь під власну відповідальність.
                    Надаю дозвіл на обробку персональних даних.
                    """
                    if let url = mailDraftURL(subject: "Заявка на вступ до Rivne Running Club", body: body) {
                        openURL(url)
                    }
                    dismiss()
                } label: {
                    Text("Зареєструватись")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .foregroundStyle(AppTheme.white)
                }
                .listRowBackground(AppTheme.green)
            }
            .navigationTitle("Стати членом клубу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрити") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Donate

struct DonateView: View {
    let supportText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                NativeCard {
                    Text(supportAttributedString(supportText))
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Підтримати клуб")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрити") { dismiss() }
                }
            }
        }
    }
}

private func supportAttributedString(_ text: String) -> AttributedString {
    var attributed = AttributedString(text)
    attributed.foregroundColor = AppTheme.black

    if let range = attributed.range(of: "5168752108112932") {
        attributed[range].inlinePresentationIntent = .stronglyEmphasized
    }
    let email = "rivnerun@gmail.com"
    if let range = attributed.range(of: email) {
        attributed[range].inlinePresentationIntent = .stronglyEmphasized
        attributed[range].foregroundColor = AppTheme.green
        attributed[range].link = mailDraftURL(subject: "Підтримка Rivne Running Club", body: "")
    }
    return attributed
}

// MARK: - Club info / records / partners

struct ClubInfoView: View {
    let title: String
    let description: String

    var body: some View {
        ScrollView {
            NativeCard {
                Text(description).foregroundStyle(AppTheme.black)
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RecordsView: View {
    let tabs: [RecordsTab]
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if tabs.isEmpty {
                ScrollView {
                    NativeCard {
                        Text("Інформація тимчасово недоступна.").foregroundStyle(AppTheme.black)
                    }
                    .padding(16)
                }
            } else {
                VStack(spacing: 0) {
                    Picker("Рекорди", selection: $selectedTab) {
                        ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                            Text(tab.title).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(12)

                    let safeIndex = min(selectedTab, tabs.count - 1)
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(Array(tabs[safeIndex].groups.enumerated()), id: \.offset) { _, group in
                                NativeCard {
                                    Text(group.heading).fontWeight(.bold).foregroundStyle(AppTheme.green)
                                    ForEach(group.records, id: \.self) { record in
                                        Text(record).foregroundStyle(AppTheme.black)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Рекорди клубу")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PartnersView: View {
    let description: String
    let partners: [PartnerItem]
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    NativeCard {
                        Text(description).foregroundStyle(AppTheme.black)
                    }
                }
                if partners.isEmpty {
                    NativeCard {
                        Text("Партнерів поки не додано.").foregroundStyle(AppTheme.black)
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(partners) { partner in
                                AsyncImage(url: URL(string: partner.logoUrl)) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFit()
                                    } else {
                                        Color.white
                                    }
                                }
                                .frame(width: 110, height: 110)
                                .padding(8)
                                .background(AppTheme.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let url = URL(string: partner.websiteUrl) { openURL(url) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Партнери")
        .navigationBarTitleDisplayMode(.inline)
    }
}
