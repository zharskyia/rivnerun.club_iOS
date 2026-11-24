import Foundation
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var snapshot = ClubSnapshot.bundled
    @State private var isRefreshing = false
    /// Set while a pull-to-refresh gesture drives the refresh, so the top banner doesn't
    /// show its own progress bar on top of the pull indicator's.
    @State private var isPullRefresh = false
    @State private var refreshMessage: String?
    @State private var showJoinSheet = false
    @State private var showDonateSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                showDonateSheet: $showDonateSheet,
                showJoinSheet: $showJoinSheet,
                onScheduleClick: { selectedTab = 3 }
            )
            .tabItem { Label("Головна", systemImage: "house") }
            .tag(0)

            ClubView(showJoinSheet: $showJoinSheet)
                .tabItem { Label("Клуб", systemImage: "figure.run") }
                .tag(1)

            EventsView()
                .tabItem { Label("Забіги", systemImage: "flag.checkered") }
                .tag(2)

            TrainingView()
                .tabItem { Label("Тренування", systemImage: "timer") }
                .tag(3)

            ContactsView()
                .tabItem { Label("Контакти", systemImage: "phone") }
                .tag(4)
        }
        .tint(AppTheme.black)
        .environment(\.clubSnapshot, snapshot)
        .environment(\.refreshSnapshot, { await refreshFromSite(fromPull: true) })
        .safeAreaInset(edge: .top) {
            if (isRefreshing && !isPullRefresh) || refreshMessage != nil {
                VStack(spacing: 0) {
                    if isRefreshing && !isPullRefresh {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                    if let refreshMessage {
                        HStack(alignment: .center, spacing: 4) {
                            Text(refreshMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.vertical, 8)
                            Spacer(minLength: 8)
                            Button("Повторити") {
                                Task { await refreshFromSite(fromPull: false) }
                            }
                            .font(.caption.bold())
                            .foregroundStyle(isRefreshing ? AppTheme.muted : AppTheme.green)
                            .disabled(isRefreshing)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .background(AppTheme.white)
            }
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinFormView()
        }
        .sheet(isPresented: $showDonateSheet) {
            DonateView(supportText: snapshot.support)
        }
        .task {
            await loadAndRefresh()
        }
    }

    private func loadAndRefresh() async {
        if let cached = loadCachedClubSnapshot() {
            snapshot = cached
        }
        await refreshFromSite(fromPull: false)
    }

    private func refreshFromSite(fromPull: Bool) async {
        guard !isRefreshing else { return }
        let previous = snapshot
        isPullRefresh = fromPull
        isRefreshing = true
        let result = await refreshClubSnapshot(previous: previous)
        snapshot = result.snapshot
        saveCachedClubSnapshot(result.snapshot)
        refreshMessage = refreshStatusMessage(result, previous: previous, now: Date())
        isRefreshing = false
        isPullRefresh = false
    }
}

// MARK: - Home

struct HomeView: View {
    @Environment(\.clubSnapshot) private var snapshot
    @Environment(\.refreshSnapshot) private var refreshSnapshot
    @Binding var showDonateSheet: Bool
    @Binding var showJoinSheet: Bool
    let onScheduleClick: () -> Void

    @State private var path: [NativeDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    HomeHeader(homeDescription: snapshot.homeDescription)
                    HeroCard(
                        description: snapshot.clubDescription,
                        onSupportClick: { showDonateSheet = true },
                        onJoinClick: { showJoinSheet = true },
                        onReadMoreClick: { path.append(.clubInfo(title: "Клуб", description: snapshot.clubDescription)) }
                    )
                    SchedulePreview(snapshot: snapshot, onScheduleClick: onScheduleClick)
                    NewsPreview(news: snapshot.news, onAllNewsClick: { path.append(.newsArchive) }, path: $path)
                    StorePreview(products: snapshot.store, onStoreClick: { path.append(.store) }, path: $path)
                    SocialLinksFooter()
                }
                .padding(.bottom, 24)
            }
            .refreshable { await refreshSnapshot() }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationDestination(for: NativeDestination.self) { destination in
                nativeDestinationView(for: destination, path: $path)
            }
        }
    }
}

private struct HomeHeader: View {
    let homeDescription: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Rivne Running Club")
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(homeDescription)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.black.opacity(0.7))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            ClubLogo()
                .containerRelativeFrame(.horizontal) { length, _ in
                    min(max(length * 0.25, 72), 100)
                }
                .aspectRatio(1, contentMode: .fit)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.yellow)
    }
}

private struct ClubLogo: View {
    var body: some View {
        // The site's real logo (logo-company.svg) is SVG, which AsyncImage can't decode —
        // this uses its PNG favicon mark instead (same site, same brand, actually renders).
        AsyncImage(url: URL(string: "https://rivnerun.club/assets/img/favicon/android-chrome-192x192.png")) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "figure.run.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AppTheme.black.opacity(0.6))
            }
        }
    }
}

private struct HeroCard: View {
    let description: String
    let onSupportClick: () -> Void
    let onJoinClick: () -> Void
    let onReadMoreClick: () -> Void

    var body: some View {
        NativeCard {
            Text("Команда, яка бігає разом").font(.title3.bold()).foregroundStyle(AppTheme.black)
            Text(firstParagraph(description)).foregroundStyle(AppTheme.black.opacity(0.8))
            HStack(spacing: 10) {
                ClubActionButton(title: "Підтримати клуб", systemImage: "banknote.fill", background: AppTheme.green, action: onSupportClick)
                ClubActionButton(title: "Стати членом клубу", systemImage: "person.fill", background: AppTheme.black, action: onJoinClick)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onReadMoreClick)
        .padding(.horizontal)
    }
}

private struct ClubActionButton: View {
    let title: String
    let systemImage: String
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(AppTheme.white)
            .background(background)
            .clipShape(RotatedCornerShape())
        }
        .buttonStyle(.plain)
    }
}

private struct SectionHeader: View {
    let title: String
    var trailing: String?
    var onTrailingClick: (() -> Void)?

    var body: some View {
        HStack {
            Text(title).font(.title3.bold()).foregroundStyle(AppTheme.black)
            Spacer()
            if let trailing {
                // Apple HIG wants at least a 44pt tap target; a bare Text at this font size is smaller.
                Button(trailing) { onTrailingClick?() }
                    .buttonStyle(.plain)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.green)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal)
    }
}

private struct SchedulePreview: View {
    let snapshot: ClubSnapshot
    let onScheduleClick: () -> Void

    var body: some View {
        let upcoming = Array(splitTrainingSchedule(snapshot.training, now: Date()).upcoming.prefix(2))
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Графік тренувань", trailing: "Увесь графік", onTrailingClick: onScheduleClick)
            VStack(spacing: 12) {
                if upcoming.isEmpty {
                    Text(noUpcomingTrainingMessage(snapshot))
                        .foregroundStyle(AppTheme.muted)
                }
                ForEach(upcoming) { session in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.day).font(.caption).foregroundStyle(AppTheme.muted)
                            Text(session.date).font(.headline.bold()).foregroundStyle(AppTheme.black)
                            Text(session.time).font(.subheadline).foregroundStyle(AppTheme.green)
                        }
                        .frame(width: 88)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title).font(.headline.bold()).foregroundStyle(AppTheme.black)
                            if !session.location.isEmpty {
                                Text(session.location).font(.subheadline).foregroundStyle(AppTheme.muted)
                            }
                            if !session.description.isEmpty {
                                Text(session.description).font(.caption).foregroundStyle(AppTheme.muted).lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(AppTheme.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppTheme.shadow, radius: 3, x: 0, y: 4)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct NewsPreview: View {
    let news: [NewsItem]
    let onAllNewsClick: () -> Void
    @Binding var path: [NativeDestination]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Останні новини", trailing: "Всі новини", onTrailingClick: onAllNewsClick)
            VStack(spacing: 12) {
                ForEach(news.prefix(3)) { item in
                    HStack(spacing: 12) {
                        ZoomableAsyncImage(url: item.imageURL)
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title).font(.headline).foregroundStyle(AppTheme.black).lineLimit(2)
                                Text(item.date).font(.caption).foregroundStyle(AppTheme.muted)
                                if let excerpt = item.excerpt {
                                    Text(excerpt).font(.caption).foregroundStyle(AppTheme.black.opacity(0.7)).lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { path.append(.newsArticle(item)) }
                    }
                    .padding(10)
                    .background(AppTheme.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppTheme.shadow, radius: 3, x: 0, y: 4)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct StorePreview: View {
    let products: [StoreItem]
    let onStoreClick: () -> Void
    @Binding var path: [NativeDestination]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Магазин", trailing: "Усі товари", onTrailingClick: onStoreClick)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(products.prefix(4)) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            AsyncImage(url: URL(string: item.imageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Rectangle().fill(AppTheme.softGreen)
                                }
                            }
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                            Text(item.title).font(.headline).foregroundStyle(AppTheme.black)
                            Text(item.price).font(.subheadline.bold()).foregroundStyle(AppTheme.green)
                        }
                        .frame(width: 150)
                        .contentShape(Rectangle())
                        .onTapGesture { path.append(.product(item)) }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Club

struct ClubView: View {
    @Environment(\.clubSnapshot) private var snapshot
    @Environment(\.refreshSnapshot) private var refreshSnapshot
    @Binding var showJoinSheet: Bool
    @State private var path: [NativeDestination] = []

    private let sections = [
        ("Історія", "/istoriya"),
        ("Засновники", "/zasnovniki"),
        ("Партнери", "/partneri"),
        ("Рекорди клубу", "/rekordi-klubu")
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Клуб").font(.largeTitle.bold()).foregroundStyle(AppTheme.black).padding(.horizontal)

                    NativeCard {
                        Text(firstParagraph(snapshot.clubDescription)).foregroundStyle(AppTheme.black)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { path.append(.clubInfo(title: "Клуб", description: snapshot.clubDescription)) }
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                            ClubSectionRow(
                                title: section.0,
                                description: sectionDescription(for: section.1),
                                dotColor: index % 2 == 0 ? AppTheme.yellow : AppTheme.green
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { path.append(destination(for: section.1)) }
                        }
                    }
                    .padding(.horizontal)

                    Button(action: { showJoinSheet = true }) {
                        Label("Стати членом клубу", systemImage: "person.badge.plus.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(AppTheme.white)
                            .background(AppTheme.black)
                            .clipShape(RotatedCornerShape())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    SocialLinksFooter()
                }
                .padding(.bottom, 24)
            }
            .refreshable { await refreshSnapshot() }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationDestination(for: NativeDestination.self) { destination in
                nativeDestinationView(for: destination, path: $path)
            }
        }
    }

    private func sectionDescription(for relativePath: String) -> String {
        switch relativePath {
        case "/rekordi-klubu":
            return "Інформація про рекорди клубу"
        case "/partneri":
            return "Інформація про партнерів клубу"
        default:
            let firstLine = snapshot.clubPages[relativePath]?
                .split(separator: "\n", omittingEmptySubsequences: true)
                .first
                .map(String.init)
            if let firstLine, !firstLine.isEmpty {
                return firstLine
            }
            return "Переглянути інформацію про розділ."
        }
    }

    private func destination(for relativePath: String) -> NativeDestination {
        if relativePath == "/rekordi-klubu" { return .records }
        if relativePath == "/partneri" { return .partners }
        let title = relativePath == "/istoriya" ? "Історія" : "Засновники"
        let description = snapshot.clubPages[relativePath] ?? "Інформація тимчасово недоступна."
        return .clubInfo(title: title, description: description)
    }
}

private struct ClubSectionRow: View {
    let title: String
    let description: String
    let dotColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(dotColor).frame(width: 12, height: 12).padding(.top, 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline.bold()).foregroundStyle(AppTheme.black)
                Text(description).font(.subheadline).foregroundStyle(AppTheme.muted).lineLimit(2)
            }
            Spacer(minLength: 0)
            Text("›").foregroundStyle(AppTheme.muted).font(.title2)
        }
        .padding(16)
        .background(AppTheme.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: AppTheme.shadow, radius: 3, x: 0, y: 4)
    }
}

// MARK: - Events

struct EventsView: View {
    @Environment(\.clubSnapshot) private var snapshot
    @Environment(\.openURL) private var openURL
    @Environment(\.refreshSnapshot) private var refreshSnapshot

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Забіги").font(.largeTitle.bold()).foregroundStyle(AppTheme.black).padding(.horizontal)

                    if snapshot.races.isEmpty {
                        NativeCard {
                            Text(
                                snapshot.hasLoadedSiteData
                                    ? "На сайті клубу наразі немає опублікованих забігів."
                                    : "Список забігів з’явиться після підключення до Інтернету."
                            )
                            .foregroundStyle(AppTheme.black)
                        }
                        .padding(.horizontal)
                    }
                    ForEach(snapshot.races) { race in
                        VStack(alignment: .leading, spacing: 10) {
                            if !race.date.isEmpty {
                                Text(race.date).font(.subheadline.bold()).foregroundStyle(AppTheme.green)
                            }
                            Text(race.title).font(.title3.bold()).foregroundStyle(AppTheme.black)
                            if !race.description.isEmpty {
                                Text(race.description).font(.body).foregroundStyle(AppTheme.black.opacity(0.75))
                            }
                            if !race.url.isEmpty {
                                Text("Детальніше та реєстрація ›").font(.subheadline.bold()).foregroundStyle(AppTheme.green)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: AppTheme.shadow, radius: 3, x: 0, y: 4)
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !race.url.isEmpty, let url = URL(string: race.url) else { return }
                            openURL(url)
                        }
                    }

                    SocialLinksFooter()
                }
                .padding(.bottom, 24)
            }
            .refreshable { await refreshSnapshot() }
            .background(AppTheme.background.ignoresSafeArea())
        }
    }
}

// MARK: - Training

struct TrainingView: View {
    @Environment(\.clubSnapshot) private var snapshot
    @Environment(\.refreshSnapshot) private var refreshSnapshot

    var body: some View {
        let schedule = splitTrainingSchedule(snapshot.training, now: Date())
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Тренування").font(.largeTitle.bold()).foregroundStyle(AppTheme.black).padding(.horizontal)

                    if schedule.upcoming.isEmpty {
                        NativeCard {
                            Text(noUpcomingTrainingMessage(snapshot)).foregroundStyle(AppTheme.black)
                        }
                        .padding(.horizontal)
                    }

                    VStack(spacing: 14) {
                        ForEach(schedule.upcoming) { session in
                            TrainingSessionCard(session: session)
                        }
                    }
                    .padding(.horizontal)

                    if !schedule.past.isEmpty {
                        Text("Вже відбулися")
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.muted)
                            .padding(.horizontal)

                        VStack(spacing: 14) {
                            ForEach(schedule.past) { session in
                                TrainingSessionCard(session: session, isPast: true)
                            }
                        }
                        .padding(.horizontal)
                    }

                    SocialLinksFooter()
                }
                .padding(.bottom, 24)
            }
            .refreshable { await refreshSnapshot() }
            .background(AppTheme.background.ignoresSafeArea())
        }
    }
}

private struct TrainingSessionCard: View {
    let session: TrainingSession
    var isPast: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(session.day), \(session.date)").font(.caption).foregroundStyle(AppTheme.muted)
                Spacer()
                Text(session.time).font(.headline.bold()).foregroundStyle(AppTheme.green)
            }
            Text(session.title).font(.title3.bold()).foregroundStyle(AppTheme.black)
            if !session.location.isEmpty {
                Text(session.location).font(.body).foregroundStyle(AppTheme.black.opacity(0.75))
            }
            if !session.description.isEmpty {
                Text(session.description).font(.body).foregroundStyle(AppTheme.black.opacity(0.75))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: AppTheme.shadow, radius: 3, x: 0, y: 4)
        .opacity(isPast ? 0.6 : 1)
    }
}

// MARK: - Contacts

struct ContactsView: View {
    @Environment(\.clubSnapshot) private var snapshot
    @Environment(\.refreshSnapshot) private var refreshSnapshot

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Контакти").font(.largeTitle.bold()).foregroundStyle(AppTheme.black).padding(.horizontal)

                    NativeCard {
                        Text(contactsAttributedString(snapshot.contacts))
                    }
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        ForEach(contactLinks) { link in
                            Link(destination: URL(string: link.url) ?? URL(string: "https://rivnerun.club")!) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: link.tint) ?? .blue)
                                            .frame(width: 42, height: 42)
                                        Image(systemName: link.icon)
                                            .foregroundStyle(AppTheme.white)
                                            .accessibilityHidden(true)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(link.name)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.black)
                                        Text(link.value)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(AppTheme.black)
                                        .accessibilityHidden(true)
                                }
                                .padding(12)
                                .background(AppTheme.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: AppTheme.shadow, radius: 3, x: 0, y: 4)
                            }
                        }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Розташування")
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.black)
                        Text("Рівне, Україна")
                            .font(.body)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .refreshable { await refreshSnapshot() }
            .background(AppTheme.background.ignoresSafeArea())
        }
    }
}

private func contactsAttributedString(_ text: String) -> AttributedString {
    var attributed = AttributedString(text)
    attributed.foregroundColor = AppTheme.black
    let email = "rivnerun@gmail.com"
    if let range = attributed.range(of: email) {
        attributed[range].inlinePresentationIntent = .stronglyEmphasized
        attributed[range].foregroundColor = AppTheme.green
        attributed[range].link = URL(string: "mailto:\(email)")
    }
    return attributed
}

#Preview {
    ContentView()
}
