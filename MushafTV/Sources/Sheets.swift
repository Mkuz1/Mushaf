import SwiftUI

/// The tablet's Recitation dialog: reciter, how far to play, and the repeats, for memorising.
struct RecitationSheet: View {
    @Environment(TVModel.self) private var model
    let close: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ReciterList()
                    } label: {
                        LabeledContent(t("Reciter"), value: model.reciterName)
                    }
                    Picker(t("Play"), selection: Binding(get: { model.audio.scope }, set: { model.setScope($0) })) {
                        ForEach(AudioController.Scope.allCases) { Text(t($0.rawValue)).tag($0) }
                    }
                    Picker(t("Repeat each ayah"), selection: Binding(get: { model.audio.verseRepeat },
                                                                     set: { model.audio.verseRepeat = $0 })) {
                        ForEach(AudioController.repeatChoices, id: \.self) { Text(AudioController.repeatLabel($0)).tag($0) }
                    }
                    Picker(t("Repeat selection"), selection: Binding(get: { model.audio.rangeRepeat },
                                                                     set: { model.audio.rangeRepeat = $0 })) {
                        ForEach(AudioController.repeatChoices, id: \.self) { Text(AudioController.repeatLabel($0)).tag($0) }
                    }
                }
                Section {
                    if model.audio.isActive {
                        Button(t("Stop recitation")) { model.audio.stop(); close() }
                    } else {
                        Button(t("Recite from this page")) { model.reciteFromPage(); close() }
                    }
                }
            }
            .navigationTitle(t("Recitation"))
        }
    }
}

struct ReciterList: View {
    @Environment(TVModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(AudioController.reciters) { r in
            Button {
                let playing = model.audio.current
                model.audio.reciter = r.id
                if let playing { model.audio.play(from: playing) }
                dismiss()
            } label: {
                HStack {
                    Text(r.localizedName)
                    Spacer()
                    if r.id == model.audio.reciter { Image(systemName: "checkmark") }
                }
            }
        }
        .navigationTitle(t("Reciter"))
    }
}

/// Language, page style, two pages, the translation and tafsir, the remote guide and the opening page.
struct SettingsSheet: View {
    @Environment(TVModel.self) private var model
    let showHelp: () -> Void
    let close: () -> Void

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section {
                    Picker(t("Language"), selection: Binding(get: { Localizer.shared.language },
                                                             set: { model.setLanguage($0) })) {
                        ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
                    }
                    Picker(t("Page style"), selection: $model.style) {
                        ForEach(PageStyle.allCases) { Text(t($0.rawValue)).tag($0) }
                    }
                    Toggle(t("Two pages side by side"), isOn: $model.dualPage)
                }
                Section {
                    Picker(t("Translation"), selection: $model.translationID) {
                        ForEach(Edition.translations) { Text($0.title).tag($0.id) }
                    }
                    Picker(t("Tafsir"), selection: $model.tafsirID) {
                        ForEach(Edition.tafsirs) { Text($0.title).tag($0.id) }
                    }
                }
                Section {
                    Button(t("How to use the remote")) { showHelp() }
                    Button(t("Opening page")) {
                        model.showDedication = true
                        close()
                    }
                } footer: {
                    Text(t("Version %@", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""))
                }
            }
            .navigationTitle(t("Settings"))
        }
    }
}

/// How to use the Siri Remote: shown once after the opening page, and from the title bar and the settings.
struct HelpView: View {
    let close: () -> Void
    @FocusState private var buttonFocused: Bool

    private struct Item: Identifiable {
        let icon: String, title: String, text: String
        var id: String { title }
        init(_ icon: String, _ title: String, _ text: String) { self.icon = icon; self.title = title; self.text = text }
    }

    private let items: [Item] = [
        Item("arrow.left.arrow.right", "Turn the pages",
         "On the pages, swipe or press left and right. Left goes forward, as in a printed mushaf."),
        Item("hand.tap", "Choose a verse",
         "Click the pages to select a verse, then swipe left and right to move from verse to verse. Click again for its options: recite from it, translation, tafsir. Back stops selecting."),
        Item("playpause", "Listen",
         "Play/Pause recites from the page, or from the selected verse, and pauses. The verse being recited is highlighted and the pages turn with it."),
        Item("arrow.up", "The top bar and the side menu",
         "Swipe up for the top bar: pages, translation and tafsir, bookmark, two pages, full screen, settings and this help. From its first button, swipe down into the side menu: surahs, juz and bookmarks."),
        Item("arrow.down", "The player",
         "Swipe down from the pages for the player: previous and next verse, play, and the recitation options (reciter, range and repeats)."),
        Item("arrow.uturn.backward", "Back",
         "Back closes a panel or a menu, and leaves full screen. On the pages, it returns to the Apple TV Home screen."),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [TV.emerald, TV.emeraldDeep], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 30) {
                HStack(spacing: 18) {
                    Image(systemName: "appletvremote.gen4").font(.system(size: 54)).foregroundStyle(TV.gold)
                    Text(t("Using the Siri Remote")).font(.system(size: 52, weight: .bold)).foregroundStyle(TV.gold)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 40), GridItem(.flexible(), spacing: 40)],
                          alignment: .leading, spacing: 34) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 22) {
                            Image(systemName: item.icon)
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(TV.emeraldDeep)
                                .frame(width: 72, height: 72)
                                .background(Circle().fill(TV.primary))
                            VStack(alignment: .leading, spacing: 8) {
                                Text(t(item.title)).font(.system(size: 30, weight: .semibold)).foregroundStyle(.white)
                                Text(t(item.text)).font(.system(size: 23)).foregroundStyle(.white.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                Button(action: close) {
                    Text(t("Got it")).font(.system(size: 28, weight: .bold)).padding(.horizontal, 40)
                }
                .buttonStyle(GoldButtonStyle())
                .focused($buttonFocused)
            }
            .padding(.horizontal, 90)
        }
        .onAppear { buttonFocused = true }
    }
}

/// The opening page's gold button.
struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { GoldBody(configuration: configuration) }

    struct GoldBody: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isFocused) private var focused
        var body: some View {
            configuration.label
                .foregroundStyle(TV.emeraldDeep)
                .padding(.vertical, 18)
                .padding(.horizontal, 30)
                .background(Capsule().fill(LinearGradient(colors: [TV.gold, Color(red: 0.98, green: 0.88, blue: 0.62), TV.gold],
                                                          startPoint: .leading, endPoint: .trailing)))
                .overlay(Capsule().strokeBorder(.white, lineWidth: focused ? 4 : 0))
                .scaleEffect(focused ? 1.08 : 1)
                .shadow(color: .black.opacity(focused ? 0.5 : 0.2), radius: focused ? 16 : 6, y: 6)
                .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}
