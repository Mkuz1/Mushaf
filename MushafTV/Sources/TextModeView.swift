import SwiftUI

/// The tablet's Translation & Tafsir view: the surah verse by verse, in Arabic, translation or both, with the
/// tafsir under each verse if wanted. Each verse takes focus (the remote scrolls through them); clicking one
/// recites from it.
struct TVTextModeView: View {
    @Environment(TVModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            header
            Rectangle().fill(TV.outline).frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(1...max(model.surah(model.textSura)?.numberOfAyahs ?? 1, 1), id: \.self) { n in
                            row(AyahKey(model.textSura, n)).id(n)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                }
                .onChange(of: model.audio.current) { _, key in
                    if let key, key.sura == model.textSura { withAnimation { proxy.scrollTo(key.ayah, anchor: .center) } }
                }
            }
        }
        .background(TV.surface)
        .task(id: "\(model.textSura)-\(model.translationID)-\(model.tafsirID)-\(model.showTafsirInText)") {
            await model.ensureTextModeTexts()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                IconButton(icon: "chevron.left", label: t("Previous surah"), size: 24) {
                    model.textSura = max(1, model.textSura - 1)
                }
                .disabled(model.textSura <= 1)
                VStack(spacing: 2) {
                    Text("\(model.textSura). \(model.surahName(model.textSura))")
                        .font(.system(size: 26, weight: .semibold))
                    if let s = model.surah(model.textSura) {
                        Text(t(s.revelationType == "Meccan" ? "Makki" : "Madani") + " · " + t("%d verses", s.numberOfAyahs))
                            .font(.system(size: 18)).foregroundStyle(TV.muted)
                    }
                }
                .foregroundStyle(TV.onSurface)
                .frame(minWidth: 280)
                IconButton(icon: "chevron.right", label: t("Next surah"), size: 24) {
                    model.textSura = min(114, model.textSura + 1)
                }
                .disabled(model.textSura >= 114)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(TextDisplay.allCases) { d in
                    Button { model.display = d } label: {
                        Text(t(d.rawValue)).font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(FocusStyle(cornerRadius: 26, selected: model.display == d, fill: TV.surfaceHigh))
                }
            }
            Button { model.showTafsirInText.toggle() } label: {
                Text(t("Tafsir")).font(.system(size: 22, weight: .semibold))
            }
            .buttonStyle(FocusStyle(cornerRadius: 26, selected: model.showTafsirInText, fill: TV.surfaceHigh))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .focusSection()
    }

    private func row(_ key: AyahKey) -> some View {
        let recited = model.audio.current == key
        let showArabic = model.display != .translation
        let showTranslation = model.display != .arabic
        let translationRTL = Edition.named(model.translationID).isRTL
        let tafsirRTL = Edition.named(model.tafsirID).isRTL
        return Button { model.recite(from: key) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(key.description).font(.system(size: 18, weight: .semibold).monospacedDigit()).foregroundStyle(.secondary)
                    .aligned(rtl: Localizer.shared.language == .arabic)
                if showArabic {
                    Text(model.text.text(Edition.arabic.id, key) ?? "…")
                        .font(TV.quran(38))
                        .lineSpacing(10)
                        .rightAligned()
                }
                if showTranslation {
                    Text(model.text.text(model.translationID, key) ?? "…")
                        .font(translationRTL ? TV.arabic(28) : .system(size: 26))
                        .lineSpacing(5)
                        .aligned(rtl: translationRTL)
                }
                if model.showTafsirInText, let tafsir = model.text.text(model.tafsirID, key) {
                    Text(tafsir)
                        .font(tafsirRTL ? TV.arabic(25) : .system(size: 22))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .aligned(rtl: tafsirRTL)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                if recited { RoundedRectangle(cornerRadius: 2).fill(TV.recited).frame(width: 5).offset(x: -14) }
            }
        }
        .buttonStyle(FocusStyle(cornerRadius: 14, selected: recited,
                                padding: EdgeInsets(top: 16, leading: 22, bottom: 16, trailing: 22),
                                fill: TV.surfaceHigh.opacity(0.6)))
    }
}
