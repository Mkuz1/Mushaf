import AVFoundation
import Observation
import SwiftUI
import UIKit

enum PageStyle: String, CaseIterable, Identifiable {
    case coloured = "Coloured", classic = "Classic", night = "Night"
    var id: String { rawValue }
}

enum ReadingMode { case mushaf, text }

enum TextDisplay: String, CaseIterable, Identifiable {
    case arabic = "Arabic", translation = "Translation", both = "Both"
    var id: String { rawValue }
}

enum PanelText: String, CaseIterable, Identifiable {
    case translation = "Translation", tafsir = "Tafsir"
    var id: String { rawValue }
}

enum SidebarTab: String, CaseIterable, Identifiable {
    case surahs = "Surahs", juz = "Juz", bookmarks = "Bookmarks"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .surahs: "list.bullet"
        case .juz: "square.grid.2x2"
        case .bookmarks: "bookmark"
        }
    }
}

/// Mus'haf on Apple TV: the same reader as the tablet app (side menu, title bar, the pages in their frame, the
/// player), worked entirely with the Siri Remote. Data, audio and translations come from the Mac app's shared
/// files (Storage, GlyphDB, AudioController, TextLibrary, PageWords, Localization).
@MainActor
@Observable
final class TVModel {
    enum Status: Equatable { case loading, ready, failed }

    private(set) var status: Status = .loading
    private(set) var db: GlyphDB?
    private(set) var meta: QuranMeta?
    let audio = AudioController()
    let text = TextLibrary()
    let words = PageWords()

    // MARK: Settings (kept between launches)

    /// The page last opened (the spread shows it with its facing page).
    var page: Int = min(max(UserDefaults.standard.integer(forKey: "page"), 1), Quran.pageCount) {
        didSet { UserDefaults.standard.set(page, forKey: "page") }
    }
    var style: PageStyle = PageStyle(rawValue: UserDefaults.standard.string(forKey: "tvTheme") ?? "") ?? .coloured {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "tvTheme") }
    }
    var dualPage: Bool = UserDefaults.standard.object(forKey: "dualPage") as? Bool ?? true {
        didSet { UserDefaults.standard.set(dualPage, forKey: "dualPage"); loadAround() }
    }
    var translationID: String = UserDefaults.standard.string(forKey: "translation")
        ?? Edition.defaults(for: Localizer.shared.language).translation {
        didSet { UserDefaults.standard.set(translationID, forKey: "translation") }
    }
    var tafsirID: String = UserDefaults.standard.string(forKey: "tafsir")
        ?? Edition.defaults(for: Localizer.shared.language).tafsir {
        didSet { UserDefaults.standard.set(tafsirID, forKey: "tafsir") }
    }
    var display: TextDisplay = TextDisplay(rawValue: UserDefaults.standard.string(forKey: "tvTextDisplay") ?? "") ?? .both {
        didSet { UserDefaults.standard.set(display.rawValue, forKey: "tvTextDisplay") }
    }
    var showTafsirInText: Bool = UserDefaults.standard.bool(forKey: "tvTextTafsir") {
        didSet { UserDefaults.standard.set(showTafsirInText, forKey: "tvTextTafsir") }
    }
    private(set) var bookmarks: Set<Int> = Set(UserDefaults.standard.array(forKey: "tvBookmarks") as? [Int] ?? []) {
        didSet { UserDefaults.standard.set(Array(bookmarks).sorted(), forKey: "tvBookmarks") }
    }
    private(set) var lastAyah: AyahKey? = UserDefaults.standard.string(forKey: "lastAyah").flatMap(AyahKey.init(string:))
    private(set) var lastListening = UserDefaults.standard.bool(forKey: "lastListening")
    var helpSeen: Bool = UserDefaults.standard.bool(forKey: "tvHelpSeen") {
        didSet { UserDefaults.standard.set(helpSeen, forKey: "tvHelpSeen") }
    }

    // MARK: What is on screen

    /// The Sadaqa Jariyah opening page, at every launch (as in the other apps) and from the settings.
    var showDedication = true
    var showSidebar = true
    var fullScreen = false
    var mode: ReadingMode = .mushaf
    var sidebarTab: SidebarTab = .surahs
    /// The remote's verse mode: started by a click on the pages; left and right then move from verse to verse.
    var ayahMode = false
    var selected: AyahKey?
    var showPanel = false
    var panelText: PanelText = .translation
    /// The surah shown in the Translation & Tafsir view.
    var textSura = 1

    /// Loaded page images, kept around the spread on screen.
    private(set) var images: [Int: UIImage] = [:]
    @ObservationIgnored private var loading: Set<Int> = []
    /// First page of each surah (1-based index), juz and hizb quarter, worked out once.
    private(set) var surahPages: [Int] = []
    private(set) var juzPages: [Int] = []
    private(set) var quarterPages: [Int] = []

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        if let scope = UserDefaults.standard.string(forKey: "tvScope").flatMap(AudioController.Scope.init(rawValue:)) {
            audio.scope = scope
        }
    }

    func bootstrap() async {
        status = .loading
        do {
            let url = Paths.data.appendingPathComponent("ayahinfo_1024.db")
            try await Downloader.fetch(Remote.ayahInfoDB, to: url)
            let db = try GlyphDB(url: url)
            self.db = db
            audio.db = db
            meta = try? await QuranMeta.load()
            surahPages = [0] + (1...114).map { db.page(of: AyahKey($0, 1)) ?? 1 }
            juzPages = meta?.juzStarts.compactMap { db.page(of: $0) } ?? []
            quarterPages = meta?.quarterStarts.compactMap { db.page(of: $0) } ?? []
            status = .ready
            loadAround()
        } catch {
            status = .failed
        }
    }

    func setLanguage(_ language: AppLanguage) {
        guard language != Localizer.shared.language else { return }
        Localizer.shared.language = language
        let d = Edition.defaults(for: language)
        translationID = d.translation
        tafsirID = d.tafsir
    }

    func setScope(_ scope: AudioController.Scope) {
        audio.scope = scope
        UserDefaults.standard.set(scope.rawValue, forKey: "tvScope")
    }

    // MARK: Pages

    /// The spread: the odd page on the right, the even one on its left, like an open mushaf.
    var rightPage: Int { dualPage ? (page % 2 == 1 ? page : page - 1) : page }
    var leftPage: Int? { dualPage && rightPage + 1 <= Quran.pageCount ? rightPage + 1 : nil }
    var visiblePages: [Int] { [rightPage] + (leftPage.map { [$0] } ?? []) }

    func go(to newPage: Int) {
        page = min(max(newPage, 1), Quran.pageCount)
        loadAround()
    }

    /// Forward is towards the end of the Quran: to the left, in an Arabic book.
    func turn(forward: Bool) {
        let step = dualPage ? 2 : 1
        go(to: rightPage + (forward ? step : -step))
    }

    var canGoForward: Bool { (leftPage ?? rightPage) < Quran.pageCount }
    var canGoBack: Bool { rightPage > 1 }

    func image(_ p: Int) -> UIImage? { images[p] }

    func loadAround() {
        let r = rightPage
        let keep = Set((r - 2)...(r + 3)).filter { (1...Quran.pageCount).contains($0) }
        images = images.filter { keep.contains($0.key) }
        for p in [r, r + 1, r + 2, r + 3, r - 2, r - 1] where keep.contains(p) { load(p) }
    }

    private func load(_ p: Int) {
        guard images[p] == nil, !loading.contains(p) else { return }
        loading.insert(p)
        Task {
            defer { loading.remove(p) }
            let dest = Paths.onlinePages.appendingPathComponent(String(format: "page%03d.png", p))
            guard let url = try? await Downloader.fetch(Remote.pageImage(p), to: dest),
                  let image = UIImage(contentsOfFile: url.path) else { return }
            images[p] = image
        }
    }

    /// The name of Allah in red (Coloured pages): the word positions come from quran.com, per page.
    func loadWords(_ p: Int) async {
        guard style == .coloured, let db else { return }
        let counts = Dictionary(uniqueKeysWithValues: db.ayahs(page: p).map { ($0, db.glyphTotal($0)) })
        await words.ensure(p, glyphCounts: counts)
    }

    // MARK: Bookmarks

    var isBookmarked: Bool { visiblePages.contains { bookmarks.contains($0) } }

    func toggleBookmark() {
        let marked = visiblePages.filter { bookmarks.contains($0) }
        if marked.isEmpty { bookmarks.insert(rightPage) } else { bookmarks.subtract(marked) }
    }

    // MARK: Verses

    func firstAyah(on p: Int) -> AyahKey? { db?.ayahs(page: p).first }

    /// Starts the verse mode on the verse being recited, else the first on the right-hand page.
    func startAyahMode() {
        if let current = audio.current, let p = db?.page(of: current), visiblePages.contains(p) {
            selected = current
        } else if !(selected.flatMap { db?.page(of: $0) }.map { visiblePages.contains($0) } ?? false) {
            selected = firstAyah(on: rightPage)
        }
        ayahMode = true
    }

    func endAyahMode() { ayahMode = false }

    func moveSelection(forward: Bool) {
        guard let db, let s = selected, let next = forward ? db.next(after: s) : db.previous(before: s) else { return }
        selected = next
        if let p = db.page(of: next), !visiblePages.contains(p) { go(to: p) }
        if showPanel { ensurePanelTexts() }
    }

    func showText(_ kind: PanelText) {
        if selected == nil { selected = firstAyah(on: rightPage) }
        panelText = kind
        showPanel = true
        ensurePanelTexts()
    }

    func ensurePanelTexts() {
        guard let key = selected else { return }
        Task {
            await text.ensure(Edition.arabic.id)
            await text.ensure(panelText == .tafsir ? tafsirID : translationID, sura: key.sura)
        }
    }

    // MARK: Translation & Tafsir view

    func toggleTextMode() {
        if mode == .mushaf {
            textSura = (selected ?? audio.current ?? firstAyah(on: rightPage))?.sura ?? 1
            mode = .text
        } else {
            mode = .mushaf
        }
    }

    func ensureTextModeTexts() async {
        await text.ensure(Edition.arabic.id)
        await text.ensure(translationID, sura: textSura)
        if showTafsirInText { await text.ensure(tafsirID, sura: textSura) }
    }

    // MARK: Recitation

    func reciteFromPage() {
        let start: AyahKey?
        if let s = selected, let p = db?.page(of: s), visiblePages.contains(p) { start = s }
        else { start = firstAyah(on: rightPage) }
        if let start { audio.play(from: start) }
    }

    func recite(from key: AyahKey) { audio.play(from: key) }

    func togglePlay() {
        if audio.isActive { audio.togglePause() } else { reciteFromPage() }
    }

    /// Keeps the recited verse on screen, and remembers it for "Continue Listening".
    func recitationMoved() {
        guard let key = audio.current else {
            lastListening = false
            UserDefaults.standard.set(false, forKey: "lastListening")
            return
        }
        lastAyah = key
        lastListening = true
        UserDefaults.standard.set(key.description, forKey: "lastAyah")
        UserDefaults.standard.set(true, forKey: "lastListening")
        if mode == .text {
            if key.sura != textSura { textSura = key.sura }
        } else if let p = db?.page(of: key), !visiblePages.contains(p) {
            go(to: p)
        }
    }

    func continueListening() {
        guard let key = lastAyah else { return }
        if let p = db?.page(of: key) { go(to: p) }
        audio.play(from: key)
    }

    // MARK: Names and captions

    func surah(_ n: Int) -> Surah? { meta?.surahs.first { $0.number == n } }

    func surahName(_ n: Int) -> String {
        guard let s = surah(n) else { return "\(n)" }
        return Localizer.shared.language == .arabic ? s.name : s.englishName
    }

    func startPage(sura: Int) -> Int { sura < surahPages.count ? surahPages[sura] : 1 }

    func juz(of p: Int) -> Int { (juzPages.lastIndex { $0 <= p } ?? 0) + 1 }
    func hizb(of p: Int) -> Int { (quarterPages.lastIndex { $0 <= p } ?? 0) / 4 + 1 }

    /// "2. Al-Baqarah · Page 2", as the tablet's title bar.
    var title: String {
        let sura = firstAyah(on: rightPage)?.sura ?? 1
        return "\(sura). \(surahName(sura)) · " + t("Page %d", rightPage)
    }

    /// "Juz' 1 · Hizb 1".
    var subtitle: String {
        t("Juz %d", juz(of: rightPage)) + " · " + t("Hizb %d", hizb(of: rightPage))
    }

    var reciterName: String {
        AudioController.reciters.first { $0.id == audio.reciter }?.localizedName ?? ""
    }

    /// "1. Al-Fatihah · Ayah 2".
    func ayahTitle(_ key: AyahKey) -> String {
        "\(key.sura). \(surahName(key.sura)) · " + t("Ayah %d", key.ayah)
    }
}
