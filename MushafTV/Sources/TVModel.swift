import AVFoundation
import Observation
import SwiftUI
import UIKit

/// Mus'haf on Apple TV: the Mushaf as a two-page spread, verse-by-verse recitation, and the surah and juz index.
/// Data, audio and translations come from the Mac app's shared files (Storage, GlyphDB, AudioController, ...).
@MainActor
@Observable
final class TVModel {
    enum Status: Equatable { case loading, ready, failed }

    private(set) var status: Status = .loading
    private(set) var db: GlyphDB?
    private(set) var meta: QuranMeta?
    let audio = AudioController()

    /// The page last opened (the spread shows it with its facing page).
    var page: Int = min(max(UserDefaults.standard.integer(forKey: "page"), 1), Quran.pageCount) {
        didSet { UserDefaults.standard.set(page, forKey: "page") }
    }
    var night: Bool = UserDefaults.standard.bool(forKey: "night") {
        didSet { UserDefaults.standard.set(night, forKey: "night") }
    }
    /// Loaded page images, kept around the spread on screen.
    private(set) var images: [Int: UIImage] = [:]
    private var loading: Set<Int> = []

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        audio.scope = .quran   // recitation continues page after page until stopped
    }

    /// The spread: the odd page on the right, the even one on its left, like an open mushaf.
    var rightPage: Int { page % 2 == 1 ? page : page - 1 }
    var leftPage: Int? { rightPage + 1 <= Quran.pageCount ? rightPage + 1 : nil }

    func bootstrap() async {
        status = .loading
        do {
            let url = Paths.data.appendingPathComponent("ayahinfo_1024.db")
            try await Downloader.fetch(Remote.ayahInfoDB, to: url)
            let db = try GlyphDB(url: url)
            self.db = db
            audio.db = db
            meta = try? await QuranMeta.load()
            status = .ready
            loadAround()
        } catch {
            status = .failed
        }
    }

    // MARK: Pages

    func go(to newPage: Int) {
        page = min(max(newPage, 1), Quran.pageCount)
        loadAround()
    }

    /// Forward is towards the end of the Quran (the left, in an Arabic book).
    func turn(forward: Bool) {
        go(to: rightPage + (forward ? 2 : -2))
    }

    func image(_ p: Int) -> UIImage? { images[p] }

    private func loadAround() {
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

    // MARK: Recitation

    func reciteFromPage() {
        guard let db, let first = db.ayahs(page: rightPage).first else { return }
        audio.play(from: first)
    }

    func togglePlay() {
        if audio.isActive { audio.togglePause() } else { reciteFromPage() }
    }

    /// Keeps the recited verse on screen.
    func followRecitation() {
        guard let key = audio.current, let p = db?.page(of: key), p != rightPage, p != leftPage else { return }
        go(to: p)
    }

    func highlights(page p: Int) -> [CGRect] {
        guard let key = audio.current, let db else { return [] }
        return db.highlightRects(for: key, page: p)
    }

    // MARK: Index

    var surahs: [Surah] { meta?.surahs ?? [] }

    func startPage(sura: Int) -> Int { db?.page(of: AyahKey(sura, 1)) ?? 1 }

    var juzPages: [Int] {
        guard let db, let meta else { return [] }
        return meta.juzStarts.compactMap { db.page(of: $0) }
    }

    /// "Al-Baqara · Page 42 · Juz 3" for the spread on screen.
    var caption: String {
        var parts: [String] = []
        if let db, let key = db.ayahs(page: rightPage).first, let s = meta?.surahs.first(where: { $0.number == key.sura }) {
            parts.append(Localizer.shared.language == .arabic ? s.name : s.englishName)
        }
        parts.append(tr("Page %d", rightPage))
        if let juz = juzPages.lastIndex(where: { $0 <= rightPage }) { parts.append(tr("Juz %d", juz + 1)) }
        return parts.joined(separator: " · ")
    }

    var reciterName: String {
        AudioController.reciters.first { $0.id == audio.reciter }?.localizedName ?? ""
    }
}
