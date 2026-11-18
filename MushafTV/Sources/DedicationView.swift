import SwiftUI

/// The opening page, as in the other apps: this app is a sadaqa jariyah (ongoing charity) on behalf of
/// Mohamad Koussa and Dima Ghannoum. The language is chosen here; then Begin (or Continue) Reading.
struct DedicationView: View {
    @Environment(TVModel.self) private var model
    @FocusState private var startFocused: Bool
    @State private var appeared = false

    private var language: AppLanguage { Localizer.shared.language }

    private var dedication: String {
        switch language {
        case .english: "On behalf of Mohamad Koussa and Dima Ghannoum\nand their families"
        case .french: "Au nom de Mohamad Koussa et Dima Ghannoum\net de leurs familles"
        case .arabic: "عن محمد كوسا وديما غنوم\nوعائلاتهم"
        }
    }

    private var duaTranslation: String? {
        switch language {
        case .english: "O Allah, place it in the scale of their good deeds."
        case .french: "Ô Allah, place-la dans la balance de leurs bonnes actions."
        case .arabic: nil
        }
    }

    private var hadithTranslation: String? {
        switch language {
        case .english: "“When a person dies, their deeds end except for three: an ongoing charity…” — Muslim"
        case .french: "« Quand l'homme meurt, ses œuvres cessent sauf trois : une aumône continue… » — Muslim"
        case .arabic: nil
        }
    }

    private var firstLaunch: Bool { model.page == 1 && model.lastAyah == nil }

    var body: some View {
        ZStack {
            LinearGradient(colors: [TV.emerald, TV.emeraldDeep], startPoint: .top, endPoint: .bottom)
            StarPattern().stroke(TV.gold.opacity(0.10), lineWidth: 1)
            RadialGradient(colors: [.clear, .black.opacity(0.45)], center: .center, startRadius: 300, endRadius: 1200)

            VStack(spacing: 18) {
                Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ").font(TV.arabic(38)).foregroundStyle(TV.gold.opacity(0.9))
                ornament
                VStack(spacing: 0) {
                    Text("صدقة جارية")
                        .font(TV.arabicBold(96))
                        .foregroundStyle(LinearGradient(colors: [TV.gold, Color(red: 0.98, green: 0.88, blue: 0.62), TV.gold],
                                                        startPoint: .leading, endPoint: .trailing))
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
                    if language != .arabic {
                        Text(language == .french ? "SADAQA JARIYA" : "SADAQA JARIYAH")
                            .font(.system(size: 18, weight: .semibold, design: .serif)).tracking(8)
                            .foregroundStyle(TV.gold.opacity(0.8))
                    }
                }
                Text(dedication)
                    .font(language == .arabic ? TV.arabicBold(40) : .system(size: 34, weight: .medium, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .foregroundStyle(.white)
                ornament
                VStack(spacing: 6) {
                    Text("اللَّهُمَّ اجْعَلْهُ فِي مِيزَانِ حَسَنَاتِهِمْ").font(TV.arabic(30)).foregroundStyle(TV.gold)
                    if let duaTranslation {
                        Text(duaTranslation).font(.system(size: 21, design: .serif)).italic().foregroundStyle(.white.opacity(0.75))
                    }
                    Text("إِذَا مَاتَ الإِنْسَانُ انْقَطَعَ عَمَلُهُ إِلَّا مِنْ ثَلَاثٍ: صَدَقَةٍ جَارِيَةٍ… — رواه مسلم")
                        .font(TV.arabic(21)).foregroundStyle(.white.opacity(0.6)).padding(.top, 6)
                    if let hadithTranslation {
                        Text(hadithTranslation).font(.system(size: 17, design: .serif)).foregroundStyle(.white.opacity(0.5))
                    }
                }
                .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    ForEach(AppLanguage.allCases) { l in
                        Button { model.setLanguage(l) } label: {
                            Text(l.nativeName).font(.system(size: 22, weight: .semibold))
                        }
                        .buttonStyle(FocusStyle(cornerRadius: 24, selected: l == language,
                                                padding: EdgeInsets(top: 10, leading: 24, bottom: 10, trailing: 24),
                                                fill: .white.opacity(0.06)))
                    }
                }
                .padding(.top, 6)

                startButtons
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 36)
            .background(RoundedRectangle(cornerRadius: 36).fill(TV.emerald.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 36).strokeBorder(TV.gold.opacity(0.55), lineWidth: 1.5))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(TV.gold.opacity(0.25), lineWidth: 1).padding(8))
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.97)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
            startFocused = true
        }
    }

    private var resumeDescription: String {
        let ayah = model.lastAyah
        let sura = ayah?.sura ?? model.firstAyah(on: model.page)?.sura
        return ([sura.map { model.surahName($0) }, t("Page %d", model.page), ayah.map { t("Ayah %d", $0.ayah) }]
            .compactMap { $0 }).joined(separator: " · ")
    }

    private var startButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                Button { begin() } label: {
                    Text(t(firstLaunch ? "Begin Reading" : "Continue Reading")).font(.system(size: 28, weight: .bold))
                }
                .buttonStyle(GoldButtonStyle())
                .focused($startFocused)
                if !firstLaunch, model.lastAyah != nil, model.lastListening {
                    Button { begin(); model.continueListening() } label: {
                        Label(t("Continue Listening"), systemImage: "play.fill").font(.system(size: 24, weight: .semibold))
                    }
                    .buttonStyle(FocusStyle(cornerRadius: 34, fill: .white.opacity(0.08)))
                }
                if !firstLaunch {
                    Button { model.go(to: 1); begin() } label: {
                        Text(t("Start from the Beginning")).font(.system(size: 22))
                    }
                    .buttonStyle(FocusStyle(cornerRadius: 30))
                }
            }
            if !firstLaunch, model.status == .ready {
                Text(resumeDescription).font(.system(size: 21)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.top, 8)
    }

    private func begin() {
        withAnimation(.easeInOut(duration: 0.4)) { model.showDedication = false }
    }

    /// A thin gold rule with a diamond, between sections.
    private var ornament: some View {
        HStack(spacing: 12) {
            Rectangle().fill(LinearGradient(colors: [.clear, TV.gold], startPoint: .leading, endPoint: .trailing)).frame(width: 160, height: 1)
            Image(systemName: "seal.fill").font(.system(size: 11)).foregroundStyle(TV.gold)
            Rectangle().fill(LinearGradient(colors: [TV.gold, .clear], startPoint: .leading, endPoint: .trailing)).frame(width: 160, height: 1)
        }
    }
}

/// Tiled eight-pointed stars (two overlapping squares), a classic Islamic geometric motif.
struct StarPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tile: CGFloat = 80
        let r: CGFloat = 28
        var y = rect.minY
        var row = 0
        while y < rect.maxY + tile {
            var x = rect.minX + (row.isMultiple(of: 2) ? 0 : tile / 2)
            while x < rect.maxX + tile {
                for rotation in [0.0, Double.pi / 4] {
                    var square = Path()
                    for i in 0..<4 {
                        let a = CGFloat(rotation + Double(i) * .pi / 2 + .pi / 4)
                        let pt = CGPoint(x: x + r * cos(a), y: y + r * sin(a))
                        if i == 0 { square.move(to: pt) } else { square.addLine(to: pt) }
                    }
                    square.closeSubpath()
                    p.addPath(square)
                }
                x += tile
            }
            y += tile / 2
            row += 1
        }
        return p
    }
}
