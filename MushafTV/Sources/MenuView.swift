import SwiftUI

/// The menu (click on the remote): recitation, the surah and juz index, reciter, night mode and language.
/// The Menu button closes it.
struct MenuView: View {
    @Environment(TVModel.self) private var model
    let close: () -> Void

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section {
                    if model.audio.isActive {
                        Button(tr("Stop recitation"), systemImage: "stop.fill") { model.audio.stop(); close() }
                    } else {
                        Button(tr("Recite from this page"), systemImage: "play.fill") { model.reciteFromPage(); close() }
                    }
                }
                Section {
                    NavigationLink { SurahList(close: close) } label: { Label(tr("Surahs"), systemImage: "list.bullet") }
                    NavigationLink { JuzList(close: close) } label: { Label(tr("Juz"), systemImage: "square.grid.3x3") }
                }
                Section(tr("Settings")) {
                    NavigationLink { ReciterList() } label: {
                        LabeledContent { Text(model.reciterName) } label: { Label(tr("Reciter"), systemImage: "person.wave.2") }
                    }
                    Toggle(isOn: $model.night) { Label(tr("Night mode"), systemImage: "moon") }
                    NavigationLink { LanguageList() } label: {
                        LabeledContent { Text(Localizer.shared.language.nativeName) } label: { Label(tr("Language"), systemImage: "globe") }
                    }
                }
            }
            .navigationTitle(model.caption)
        }
    }
}

struct SurahList: View {
    @Environment(TVModel.self) private var model
    let close: () -> Void

    var body: some View {
        List(model.surahs) { s in
            Button {
                model.go(to: model.startPage(sura: s.number))
                close()
            } label: {
                HStack(spacing: 24) {
                    Text("\(s.number)").monospacedDigit().foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                    VStack(alignment: .leading) {
                        Text(s.englishName)
                        Text(s.englishNameTranslation).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(s.name).font(.title3)
                }
            }
        }
        .navigationTitle(tr("Surahs"))
    }
}

struct JuzList: View {
    @Environment(TVModel.self) private var model
    let close: () -> Void

    var body: some View {
        List(Array(model.juzPages.enumerated()), id: \.offset) { item in
            Button {
                model.go(to: item.element)
                close()
            } label: {
                LabeledContent(tr("Juz %d", item.offset + 1)) { Text(tr("Page %d", item.element)) }
            }
        }
        .navigationTitle(tr("Juz"))
    }
}

struct ReciterList: View {
    @Environment(TVModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(AudioController.reciters) { r in
            Button {
                let wasPlaying = model.audio.current
                model.audio.reciter = r.id
                if let key = wasPlaying { model.audio.play(from: key) }
                dismiss()
            } label: {
                HStack {
                    Text(r.localizedName)
                    Spacer()
                    if r.id == model.audio.reciter { Image(systemName: "checkmark") }
                }
            }
        }
        .navigationTitle(tr("Reciter"))
    }
}

struct LanguageList: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(AppLanguage.allCases) { l in
            Button {
                Localizer.shared.language = l
                dismiss()
            } label: {
                HStack {
                    Text(l.nativeName)
                    Spacer()
                    if l == Localizer.shared.language { Image(systemName: "checkmark") }
                }
            }
        }
        .navigationTitle(tr("Language"))
    }
}
