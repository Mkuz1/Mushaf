import SwiftUI
import UIKit

@main
struct MushafTVApp: App {
    @State private var model = TVModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.bootstrap() }
                // A reader: the screen saver doesn't cover the page being read.
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}

/// A button with no focus effect: the Mushaf spread is the whole screen.
struct PlainScreenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

struct RootView: View {
    @Environment(TVModel.self) private var model
    @State private var showMenu = false
    @State private var showHint = true

    var body: some View {
        ZStack {
            (model.night ? Color.black : Color(red: 0.05, green: 0.16, blue: 0.12)).ignoresSafeArea()
            switch model.status {
            case .loading:
                ProgressView(tr("Loading…"))
            case .failed:
                VStack(spacing: 30) {
                    Text(tr("Couldn't load the Mushaf. Check the connection.")).font(.title3)
                    Button(tr("Try Again")) { Task { await model.bootstrap() } }
                }
            case .ready:
                Button { showMenu = true } label: { SpreadView() }
                    .buttonStyle(PlainScreenButtonStyle())
                    .onMoveCommand { direction in
                        switch direction {
                        case .left: model.turn(forward: true)
                        case .right: model.turn(forward: false)
                        default: break
                        }
                        showHint = false
                    }
                    .onPlayPauseCommand { model.togglePlay(); showHint = false }
            }
        }
        .overlay(alignment: .bottom) {
            if model.status == .ready && showHint {
                Text(tr("Swipe to turn pages · Play/Pause to recite · Click for the menu"))
                    .font(.callout)
                    .padding(.horizontal, 30).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 30)
                    .transition(.opacity)
            }
        }
        .task(id: model.status) {
            guard model.status == .ready else { return }
            try? await Task.sleep(for: .seconds(8))
            withAnimation { showHint = false }
        }
        .onChange(of: model.audio.current) { _, _ in model.followRecitation() }
        .fullScreenCover(isPresented: $showMenu) {
            MenuView(close: { showMenu = false })
                .environment(model)
                .environment(\.layoutDirection, Localizer.shared.language.layoutDirection)
                .presentationBackground(Color(red: 0.05, green: 0.16, blue: 0.12))
        }
        #if DEBUG
        // Screenshots (simulator, Debug builds only): -showMenu YES opens the menu, -recite YES starts recitation.
        .task(id: model.status) {
            guard model.status == .ready else { return }
            if UserDefaults.standard.bool(forKey: "showMenu") { showMenu = true }
            if UserDefaults.standard.bool(forKey: "recite") { showHint = false; model.reciteFromPage() }
        }
        #endif
    }
}

/// The two pages, the caption under them, and the recitation in progress.
struct SpreadView: View {
    @Environment(TVModel.self) private var model

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                if let left = model.leftPage { PageView(page: left) } else { Color.clear.aspectRatio(1024.0 / 1656.0, contentMode: .fit) }
                PageView(page: model.rightPage)
            }
            .frame(maxHeight: .infinity)
            HStack(spacing: 24) {
                Text(model.caption)
                if model.audio.isActive {
                    Label(model.reciterName, systemImage: model.audio.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .foregroundStyle(Color(red: 0.93, green: 0.82, blue: 0.55))
                }
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PageView: View {
    @Environment(TVModel.self) private var model
    let page: Int

    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.95, blue: 0.86)
            if let image = model.image(page) {
                Image(uiImage: image).resizable().interpolation(.high)
                    .overlay { highlight }
            } else {
                ProgressView()
            }
        }
        .aspectRatio(1024.0 / 1656.0, contentMode: .fit)
        .modifier(NightModifier(on: model.night))
        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
    }

    /// The verse being recited, line by line (ayahinfo rectangles are in 1024-pixel page coordinates).
    private var highlight: some View {
        GeometryReader { g in
            let s = g.size.width / 1024
            ForEach(Array(model.highlights(page: page).enumerated()), id: \.offset) { item in
                let r = item.element
                RoundedRectangle(cornerRadius: 4 * s)
                    .fill(Color(red: 0.16, green: 0.55, blue: 0.4).opacity(0.28))
                    .frame(width: r.width * s, height: r.height * s)
                    .position(x: r.midX * s, y: r.midY * s)
            }
        }
    }
}

struct NightModifier: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.colorInvert().opacity(0.9) } else { content }
    }
}
