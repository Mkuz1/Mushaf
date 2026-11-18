import SwiftUI
import UIKit

/// The pages on their desk, as on the tablet: the spread (odd page on the right), each page framed in gold and
/// green (Coloured), the verse being recited and the selected verse highlighted.
struct ReaderView: View {
    @Environment(TVModel.self) private var model
    /// The pages have the remote's focus (they show it with a mint rule and the hint below).
    let focused: Bool

    var body: some View {
        ZStack {
            TV.deskColor(model.style)
            HStack(spacing: model.style == .coloured ? 10 : 2) {
                // Book order whatever the interface language: the later page on the left.
                if let left = model.leftPage { TVPageView(page: left, outerEdgeIsRight: false) }
                TVPageView(page: model.rightPage, outerEdgeIsRight: true)
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 28)
            .padding(.vertical, model.fullScreen ? 30 : 18)
        }
        .overlay {
            if focused {
                RoundedRectangle(cornerRadius: 6).strokeBorder(TV.primary.opacity(0.9), lineWidth: 4)
            }
        }
        .overlay(alignment: .bottom) {
            if focused {
                Text(hint)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(TV.onSurface)
                    .padding(.horizontal, 24).padding(.vertical, 8)
                    .background(TV.surface.opacity(0.88), in: Capsule())
                    .padding(.bottom, 6)
            }
        }
    }

    private var hint: String {
        if model.fullScreen && !model.ayahMode { return t("Back: leave full screen") }
        return model.ayahMode ? t("◀ ▶ move between verses · Click: options · Back: done")
            : t("◀ ▶ turn the pages · Click: choose a verse · ▲ top bar · ▼ player")
    }
}

/// One page: the image (ink black, or light on Night), the name of Allah in red, the highlights, the frame and
/// the bookmark ribbon.
struct TVPageView: View {
    @Environment(TVModel.self) private var model
    let page: Int
    /// Side of the page facing away from the spine: where the ribbon hangs.
    let outerEdgeIsRight: Bool

    private static let aspect = Quran.pageImageSize.width / Quran.pageImageSize.height

    var body: some View {
        framed(content)
            .overlay(alignment: outerEdgeIsRight ? .topTrailing : .topLeading) {
                if model.bookmarks.contains(page) || model.style == .coloured {
                    Ribbon(marked: model.bookmarks.contains(page))
                        .frame(width: 26, height: 64)
                        .offset(y: -4)
                        .padding(.horizontal, 22)
                }
            }
            .task(id: "\(page)-\(model.style.rawValue)-\(model.status == .ready)") { await model.loadWords(page) }
    }

    private var ink: Color {
        model.style == .night ? .white.opacity(0.9) : .black
    }

    private var paper: Color {
        switch model.style {
        case .coloured: TV.parchment
        case .classic: TV.paperLight
        case .night: TV.night
        }
    }

    private var content: some View {
        ZStack {
            paper
            if let image = model.image(page) {
                Image(uiImage: image).resizable().interpolation(.high).renderingMode(.template).foregroundStyle(ink)
                allahLayer(image)
                highlights
            } else {
                ProgressView()
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
    }

    @ViewBuilder
    private func framed<V: View>(_ inner: V) -> some View {
        if model.style == .coloured {
            inner
                .padding(14)
                .background(TV.parchment)
                .overlay(Rectangle().strokeBorder(TV.frameGold, lineWidth: 3))
                .overlay(Rectangle().strokeBorder(TV.frameGreen, lineWidth: 1).padding(6))
                .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
                .aspectRatio(contentMode: .fit)
        } else {
            inner.shadow(color: .black.opacity(model.style == .night ? 0 : 0.2), radius: 4, y: 2)
        }
    }

    /// The page's own ink, in red, masked to each name of Allah (Coloured pages).
    @ViewBuilder
    private func allahLayer(_ image: UIImage) -> some View {
        if model.style == .coloured, let refs = model.words.allahWords[page], !refs.isEmpty, let db = model.db {
            let rects = db.glyphs(page: page)
                .filter { refs.contains(WordRef(key: $0.key, position: $0.position)) }
                .map(\.rect)
            Image(uiImage: image).resizable().interpolation(.high).renderingMode(.template)
                .foregroundStyle(TV.allahRed)
                .mask {
                    Canvas { ctx, size in
                        let s = size.width / Quran.pageImageSize.width
                        for r in rects {
                            let v = CGRect(x: r.minX * s, y: r.minY * s, width: r.width * s, height: r.height * s)
                            ctx.fill(Path(v.insetBy(dx: -1, dy: -2)), with: .color(.white))
                        }
                    }
                }
        }
    }

    /// The verse being recited (green, as on the tablet) and the one chosen with the remote (gold).
    private var highlights: some View {
        let db = model.db
        let recited = model.audio.current.flatMap { db?.highlightRects(for: $0, page: page) } ?? []
        let chosen = model.ayahMode ? (model.selected.flatMap { db?.highlightRects(for: $0, page: page) } ?? []) : []
        return Canvas { ctx, size in
            let s = size.width / Quran.pageImageSize.width
            func view(_ r: CGRect) -> CGRect {
                CGRect(x: r.minX * s, y: r.minY * s, width: r.width * s, height: r.height * s).insetBy(dx: -3, dy: -2)
            }
            for r in recited {
                ctx.fill(Path(roundedRect: view(r), cornerRadius: 4), with: .color(TV.recited.opacity(0.42)))
            }
            for r in chosen {
                let path = Path(roundedRect: view(r), cornerRadius: 4)
                ctx.fill(path, with: .color(TV.gold.opacity(0.30)))
                ctx.stroke(path, with: .color(TV.frameGold), lineWidth: 2.5)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The silk bookmark ribbon with a notched tail: red when the page is bookmarked, faint otherwise.
struct Ribbon: View {
    let marked: Bool

    var body: some View {
        let shape = RibbonShape()
        if marked {
            shape.fill(LinearGradient(colors: [Color(red: 0.70, green: 0.10, blue: 0.12), Color(red: 0.52, green: 0.05, blue: 0.08)],
                                      startPoint: .leading, endPoint: .trailing))
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        } else {
            shape.fill(Color.gray.opacity(0.18)).overlay(shape.stroke(Color.gray.opacity(0.45), lineWidth: 1))
        }
    }
}

struct RibbonShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.width * 0.6))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
