import SwiftUI
import UIKit

@main
struct MushafTVApp: App {
    @State private var model = TVModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .task { await model.bootstrap() }
                // A reader: the screen saver doesn't cover the page being read.
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}

struct RootView: View {
    @Environment(TVModel.self) private var model

    var body: some View {
        ZStack {
            TV.surface.ignoresSafeArea()
            if model.showDedication {
                DedicationView().transition(.opacity)
            } else {
                switch model.status {
                case .loading:
                    ProgressView(t("Loading…")).foregroundStyle(TV.onSurface)
                case .failed:
                    VStack(spacing: 30) {
                        Text(t("Couldn't load the Mushaf. Check the connection.")).font(.system(size: 30)).foregroundStyle(TV.onSurface)
                        Button(t("Try Again")) { Task { await model.bootstrap() } }
                            .buttonStyle(FocusStyle(cornerRadius: 30, fill: TV.surfaceHigh))
                    }
                case .ready:
                    MainView()
                }
            }
        }
        // Arabic lays the interface out right to left; the pages keep book order.
        .environment(\.layoutDirection, Localizer.shared.language.layoutDirection)
        #if DEBUG
        // App Store screenshots (simulator, Debug builds only): -screen dedication|reader|recite|text|panel|help.
        .task(id: model.status) {
            guard model.status == .ready, let screen = UserDefaults.standard.string(forKey: "screen"),
                  screen != "dedication" else { return }
            model.showDedication = false
            try? await Task.sleep(for: .seconds(2))
            switch screen {
            case "recite": model.reciteFromPage()
            case "text": model.toggleTextMode()
            case "panel":
                model.startAyahMode()
                model.moveSelection(forward: true)
                model.showText(.translation)
            default: break
            }
        }
        #endif
    }
}
