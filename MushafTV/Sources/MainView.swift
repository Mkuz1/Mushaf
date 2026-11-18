import SwiftUI

/// The reader, laid out as the tablet app: the side menu (surahs, juz, bookmarks), the title bar, the pages and
/// the player; the verse panel (translation or tafsir) on the side when open.
///
/// The remote: on the pages, left and right turn the pages (or, after a click, move from verse to verse), so the
/// side menu and the panel take no focus while the pages have it; up reaches the title bar, down the player, and
/// from the title bar's first button down leads into the side menu.
struct MainView: View {
    @Environment(TVModel.self) private var model
    @FocusState private var readerFocused: Bool
    @State private var sheet: SheetKind?
    @State private var showAyahActions = false

    enum SheetKind: String, Identifiable {
        case recitation, settings, help
        var id: String { rawValue }
    }

    var body: some View {
        HStack(spacing: 0) {
            if !model.fullScreen && model.showSidebar {
                SidebarView(onPick: { readerFocused = model.mode == .mushaf })
                    .frame(width: 440)
                    .background(TV.surface)
                    .disabled(readerFocused)
                Rectangle().fill(TV.outline).frame(width: 1)
            }
            VStack(spacing: 0) {
                if !model.fullScreen {
                    TopBar(sheet: $sheet)
                    Rectangle().fill(TV.outline).frame(height: 1)
                }
                HStack(spacing: 0) {
                    if model.mode == .mushaf { reader } else { TVTextModeView() }
                    if model.showPanel {
                        Rectangle().fill(TV.outline).frame(width: 1)
                        VersePanel(onClose: closePanel)
                            .frame(width: 560)
                            .background(TV.surface)
                            .disabled(readerFocused)
                    }
                }
                if !model.fullScreen {
                    Rectangle().fill(TV.outline).frame(height: 1)
                    DockView(sheet: $sheet)
                }
            }
        }
        .background(TV.surface.ignoresSafeArea())
        .onPlayPauseCommand { model.togglePlay() }
        .onChange(of: model.audio.current) { _, _ in model.recitationMoved() }
        .onChange(of: model.mode) { _, mode in if mode == .mushaf { focusReader() } }
        .onChange(of: model.fullScreen) { _, _ in focusReader() }
        .onAppear {
            focusReader()
            if !model.helpSeen { sheet = .help }
        }
        .fullScreenCover(item: $sheet, onDismiss: {
            model.helpSeen = true
            focusReader()
        }) { kind in
            Group {
                switch kind {
                case .recitation: RecitationSheet(close: { sheet = nil })
                case .settings: SettingsSheet(showHelp: { sheet = .help }, close: { sheet = nil })
                case .help: HelpView(close: { sheet = nil })
                }
            }
            .environment(model)
            .environment(\.layoutDirection, Localizer.shared.language.layoutDirection)
            .presentationBackground(TV.surface)
        }
        .confirmationDialog(model.selected.map { model.ayahTitle($0) } ?? "", isPresented: $showAyahActions,
                            titleVisibility: .visible) {
            if let key = model.selected {
                Button(t("Recite from this verse")) { model.recite(from: key) }
                Button(t("Translation")) { model.showText(.translation) }
                Button(t("Tafsir")) { model.showText(.tafsir) }
                Button(model.bookmarks.contains(model.db?.page(of: key) ?? 0) ? t("Remove bookmark") : t("Bookmark this page")) {
                    model.toggleBookmark()
                }
            }
            Button(t("Cancel"), role: .cancel) {}
        }
    }

    private var reader: some View {
        Button(action: readerClicked) { ReaderView(focused: readerFocused) }
            .buttonStyle(BareButtonStyle())
            .focused($readerFocused)
            .onMoveCommand { direction in
                switch direction {
                case .left: model.ayahMode ? model.moveSelection(forward: true) : model.turn(forward: true)
                case .right: model.ayahMode ? model.moveSelection(forward: false) : model.turn(forward: false)
                default: break
                }
            }
            // Back: ends the verse mode, closes the panel, leaves full screen; otherwise it is tvOS's own (Home).
            .onExitCommand(perform: model.ayahMode || model.showPanel || model.fullScreen ? { readerBack() } : nil)
    }

    private func readerClicked() {
        if model.ayahMode { showAyahActions = true } else { model.startAyahMode() }
    }

    private func readerBack() {
        if model.ayahMode { model.endAyahMode() }
        else if model.showPanel { model.showPanel = false }
        else if model.fullScreen { model.fullScreen = false }
    }

    private func closePanel() {
        model.showPanel = false
        focusReader()
    }

    private func focusReader() {
        guard model.mode == .mushaf else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            readerFocused = true
        }
    }
}

// MARK: - Title bar

/// "2. Al-Baqarah · Page 2 / Juz' 1 · Hizb 1" and the tablet's buttons: side menu, ‹ page ›, Translation &
/// Tafsir, bookmark, two pages, full screen, settings, help.
struct TopBar: View {
    @Environment(TVModel.self) private var model
    @Binding var sheet: MainView.SheetKind?

    var body: some View {
        HStack(spacing: 14) {
            IconButton(icon: "sidebar.leading", label: t("Side menu"), selected: model.showSidebar) {
                withAnimation { model.showSidebar.toggle() }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.title).font(.system(size: 32, weight: .medium)).lineLimit(1)
                Text(model.subtitle).font(.system(size: 21)).foregroundStyle(TV.muted)
            }
            .foregroundStyle(TV.onSurface)
            Spacer(minLength: 20)
            // ‹ page ›, in book order whatever the interface language: left goes forward.
            HStack(spacing: 10) {
                IconButton(icon: "chevron.left", label: t("Next page")) { model.turn(forward: true) }
                    .disabled(!model.canGoForward)
                Text("\(model.rightPage)")
                    .font(.system(size: 28, weight: .medium).monospacedDigit())
                    .foregroundStyle(TV.onSurface)
                    .frame(minWidth: 92, minHeight: 64)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(TV.muted.opacity(0.6), lineWidth: 1.5))
                IconButton(icon: "chevron.right", label: t("Previous page")) { model.turn(forward: false) }
                    .disabled(!model.canGoBack)
            }
            .environment(\.layoutDirection, .leftToRight)
            IconButton(icon: model.mode == .mushaf ? "text.book.closed" : "book",
                       label: model.mode == .mushaf ? t("Translation & Tafsir") : t("Mushaf"),
                       selected: model.mode == .text) { model.toggleTextMode() }
            IconButton(icon: model.isBookmarked ? "bookmark.fill" : "bookmark", label: t("Bookmark"),
                       selected: model.isBookmarked) { model.toggleBookmark() }
            IconButton(icon: "book.pages", label: t("Two pages"), selected: model.dualPage) { model.dualPage.toggle() }
            IconButton(icon: "arrow.up.left.and.arrow.down.right", label: t("Full screen")) {
                model.mode = .mushaf
                model.fullScreen = true
            }
            IconButton(icon: "gearshape", label: t("Settings")) { sheet = .settings }
            IconButton(icon: "questionmark.circle", label: t("Help")) { sheet = .help }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(TV.surface)
        .focusSection()
    }
}

// MARK: - Side menu

/// Tabs (surahs, juz, bookmarks) over the list, as the tablet's side menu.
struct SidebarView: View {
    @Environment(TVModel.self) private var model
    /// After a choice: back to the pages.
    let onPick: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(SidebarTab.allCases) { tab in
                    Button { model.sidebarTab = tab } label: {
                        Label(t(tab.rawValue), systemImage: tab.icon)
                            .font(.system(size: 21, weight: .semibold))
                            .labelStyle(.iconOnly)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FocusStyle(cornerRadius: 30, selected: model.sidebarTab == tab,
                                            padding: EdgeInsets(top: 14, leading: 10, bottom: 14, trailing: 10),
                                            fill: TV.surfaceHigh))
                }
            }
            Text(t(model.sidebarTab.rawValue))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(TV.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        switch model.sidebarTab {
                        case .surahs: surahs
                        case .juz: juz
                        case .bookmarks: bookmarks
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
                }
                .onAppear { scrollToCurrent(proxy) }
                .onChange(of: model.sidebarTab) { _, _ in scrollToCurrent(proxy) }
            }
        }
        .padding(.top, 18)
        .padding(.horizontal, 14)
        .focusSection()
    }

    private var currentSura: Int { model.firstAyah(on: model.rightPage)?.sura ?? 1 }

    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        switch model.sidebarTab {
        case .surahs: proxy.scrollTo("s\(currentSura)", anchor: .center)
        case .juz: proxy.scrollTo("j\(model.juz(of: model.rightPage))", anchor: .center)
        case .bookmarks: break
        }
    }

    @ViewBuilder private var surahs: some View {
        ForEach(model.surahs) { s in
            Button {
                model.go(to: model.startPage(sura: s.number))
                onPick()
            } label: {
                HStack(spacing: 16) {
                    Text("\(s.number)")
                        .font(.system(size: 19, weight: .medium).monospacedDigit())
                        .frame(width: 48, height: 48)
                        .overlay(Circle().strokeBorder(lineWidth: 1.5))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.englishName).font(.system(size: 25, weight: .semibold)).lineLimit(1)
                        Text(meta(s)).font(.system(size: 18)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    Text(s.name).font(TV.arabic(27)).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(FocusStyle(cornerRadius: 12, selected: s.number == currentSura,
                                    padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 14)))
            .id("s\(s.number)")
        }
    }

    /// "Madani · 286 verses · Page 2".
    private func meta(_ s: Surah) -> String {
        [t(s.revelationType == "Meccan" ? "Makki" : "Madani"), t("%d verses", s.numberOfAyahs),
         t("Page %d", model.startPage(sura: s.number))].joined(separator: " · ")
    }

    @ViewBuilder private var juz: some View {
        ForEach(Array(model.juzPages.enumerated()), id: \.offset) { item in
            let n = item.offset + 1
            Button {
                model.go(to: item.element)
                onPick()
            } label: {
                HStack(spacing: 16) {
                    Text("\(n)")
                        .font(.system(size: 19, weight: .medium).monospacedDigit())
                        .frame(width: 48, height: 48)
                        .overlay(Circle().strokeBorder(lineWidth: 1.5))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("Juz %d", n)).font(.system(size: 25, weight: .semibold))
                        Text(pageLine(item.element)).font(.system(size: 18)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(FocusStyle(cornerRadius: 12, selected: n == model.juz(of: model.rightPage),
                                    padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 14)))
            .id("j\(n)")
        }
    }

    /// "Page 42 · Al-Baqarah".
    private func pageLine(_ p: Int) -> String {
        let sura = model.firstAyah(on: p)?.sura ?? 1
        return t("Page %d", p) + " · " + model.surahName(sura)
    }

    @ViewBuilder private var bookmarks: some View {
        if model.bookmarks.isEmpty {
            Text(t("No bookmarks yet. Add one with the bookmark button in the top bar."))
                .font(.system(size: 22))
                .foregroundStyle(TV.muted)
                .multilineTextAlignment(.center)
                .padding(30)
        } else {
            ForEach(model.bookmarks.sorted(), id: \.self) { p in
                Button {
                    model.go(to: p)
                    onPick()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "bookmark.fill").font(.system(size: 24))
                            .foregroundStyle(Color(red: 0.75, green: 0.15, blue: 0.15))
                            .frame(width: 48)
                        Text(pageLine(p)).font(.system(size: 24, weight: .semibold)).lineLimit(1)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(FocusStyle(cornerRadius: 12, selected: model.visiblePages.contains(p),
                                        padding: EdgeInsets(top: 14, leading: 12, bottom: 14, trailing: 14)))
            }
        }
    }
}

extension TVModel {
    var surahs: [Surah] { meta?.surahs ?? [] }
}

// MARK: - Player

/// The tablet's player: previous verse, play (the mint button), next verse, what is being recited, and the
/// recitation options.
struct DockView: View {
    @Environment(TVModel.self) private var model
    @Binding var sheet: MainView.SheetKind?

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 14) {
                IconButton(icon: "backward.end.fill", label: t("Previous verse"), size: 26) { model.audio.skip(false) }
                    .disabled(!model.audio.isActive)
                Button { model.togglePlay() } label: {
                    Image(systemName: model.audio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 34, weight: .bold))
                        .frame(width: 84, height: 84)
                }
                .buttonStyle(PlayButtonStyle())
                IconButton(icon: "forward.end.fill", label: t("Next verse"), size: 26) { model.audio.skip(true) }
                    .disabled(!model.audio.isActive)
            }
            .environment(\.layoutDirection, .leftToRight)
            if let key = model.audio.current {
                Image(systemName: "waveform").font(.system(size: 26)).foregroundStyle(TV.primary)
                    .symbolEffect(.variableColor.iterative, isActive: model.audio.isPlaying)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.ayahTitle(key)).font(.system(size: 25, weight: .semibold)).foregroundStyle(TV.onSurface)
                    Text(model.reciterName).font(.system(size: 20)).foregroundStyle(TV.gold)
                }
                .lineLimit(1)
            } else {
                Text(t("Click the pages to choose a verse · Play/Pause to recite"))
                    .font(.system(size: 22)).foregroundStyle(TV.muted).lineLimit(1)
            }
            Spacer(minLength: 10)
            if model.audio.isLoading { ProgressView() }
            if let error = model.audio.errorMessage {
                Text(error).font(.system(size: 18)).foregroundStyle(.red.opacity(0.8)).lineLimit(1)
            }
            Button { sheet = .recitation } label: {
                Label(t("Recitation"), systemImage: "slider.horizontal.3").font(.system(size: 23, weight: .semibold))
            }
            .buttonStyle(FocusStyle(cornerRadius: 34, fill: TV.surfaceHighest))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(TV.surfaceHigh)
        .focusSection()
    }
}

/// The mint play button of the tablet's player.
struct PlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { PlayBody(configuration: configuration) }

    struct PlayBody: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isFocused) private var focused
        var body: some View {
            configuration.label
                .foregroundStyle(TV.onPrimary)
                .background(Circle().fill(TV.primary))
                .overlay(Circle().strokeBorder(.white, lineWidth: focused ? 5 : 0))
                .scaleEffect(focused ? 1.1 : 1)
                .shadow(color: .black.opacity(focused ? 0.5 : 0), radius: 12, y: 6)
                .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}

// MARK: - Verse panel

/// The selected verse with its translation or tafsir, beside the pages (the tablet's inspector). Its paragraphs
/// take focus, so the remote scrolls through a long tafsir; Back closes it.
struct VersePanel: View {
    @Environment(TVModel.self) private var model
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(model.selected.map { model.ayahTitle($0) } ?? "")
                    .font(.system(size: 26, weight: .semibold)).foregroundStyle(TV.onSurface).lineLimit(1)
                Spacer()
                IconButton(icon: "xmark", label: t("Close"), size: 22, action: onClose)
            }
            HStack(spacing: 10) {
                ForEach(PanelText.allCases) { kind in
                    Button { model.showText(kind) } label: {
                        Text(t(kind.rawValue)).font(.system(size: 22, weight: .semibold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FocusStyle(cornerRadius: 26, selected: model.panelText == kind, fill: TV.surfaceHigh))
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let key = model.selected {
                        if let arabic = model.text.text(Edition.arabic.id, key) {
                            Text(arabic)
                                .font(TV.quran(36))
                                .foregroundStyle(TV.onSurface)
                                .multilineTextAlignment(.trailing)
                                .lineSpacing(10)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .environment(\.layoutDirection, .rightToLeft)
                        }
                        let id = model.panelText == .tafsir ? model.tafsirID : model.translationID
                        if let passage = model.text.text(id, key) {
                            Text(Edition.named(id).title).font(.system(size: 18)).foregroundStyle(TV.muted)
                            ForEach(Array(paragraphs(passage).enumerated()), id: \.offset) { item in
                                Button {} label: {
                                    Text(item.element)
                                        .font(Edition.named(id).isRTL ? TV.arabic(28) : .system(size: 25))
                                        .lineSpacing(6)
                                        .multilineTextAlignment(Edition.named(id).isRTL ? .trailing : .leading)
                                        .frame(maxWidth: .infinity,
                                               alignment: Edition.named(id).isRTL ? .trailing : .leading)
                                }
                                .buttonStyle(FocusStyle(cornerRadius: 12, padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12),
                                                        fill: TV.surfaceHigh.opacity(0.5)))
                            }
                        } else {
                            HStack { ProgressView(); Text(t("Loading the text…")).foregroundStyle(TV.muted) }
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .padding(22)
        .focusSection()
        .onExitCommand(perform: onClose)
    }

    private func paragraphs(_ s: String) -> [String] {
        s.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
