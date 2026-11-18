import SwiftUI

/// The tablet app's colours (its dark green Material theme, seeded with the icon's emerald #0D785C) and the
/// mushaf's own (flutter_app/lib/ui/common.dart, AppColors).
enum TV {
    static let surface = Color(red: 0.059, green: 0.082, blue: 0.075)        // #0F1513
    static let surfaceHigh = Color(red: 0.106, green: 0.129, blue: 0.122)    // #1B211F
    static let surfaceHighest = Color(red: 0.157, green: 0.188, blue: 0.176)
    static let primary = Color(red: 0.522, green: 0.839, blue: 0.722)        // mint #85D6B8
    static let onPrimary = Color(red: 0.0, green: 0.22, blue: 0.157)
    static let selected = Color(red: 0.204, green: 0.294, blue: 0.263)       // #344B43
    static let onSurface = Color(red: 0.871, green: 0.894, blue: 0.878)
    static let muted = Color(red: 0.62, green: 0.66, blue: 0.64)
    static let outline = Color.white.opacity(0.14)
    static let accent = Color(red: 0.051, green: 0.471, blue: 0.361)         // #0D785C
    static let gold = Color(red: 0.859, green: 0.722, blue: 0.420)           // #DBB86B
    static let emerald = Color(red: 0.031, green: 0.200, blue: 0.149)        // #083326
    static let emeraldDeep = Color(red: 0.012, green: 0.110, blue: 0.078)    // #031C14
    static let parchment = Color(red: 0.961, green: 0.910, blue: 0.788)      // #F5E8C9
    static let paperLight = Color(red: 0.988, green: 0.969, blue: 0.910)     // #FCF7E8
    static let desk = Color(red: 0.800, green: 0.722, blue: 0.580)           // #CCB894
    static let night = Color(red: 0.078, green: 0.078, blue: 0.090)          // #141417
    static let frameGold = Color(red: 0.690, green: 0.541, blue: 0.239)      // #B08A3D
    static let frameGreen = Color(red: 0.239, green: 0.420, blue: 0.290)     // #3D6B4A
    static let allahRed = Color(red: 0.780, green: 0.129, blue: 0.102)       // #C7211A
    static let recited = Color(red: 0.42, green: 0.74, blue: 0.47)

    static func quran(_ size: CGFloat) -> Font { .custom("Amiri Quran", size: size) }
    static func arabic(_ size: CGFloat) -> Font { .custom("Amiri", size: size) }
    static func arabicBold(_ size: CGFloat) -> Font { .custom("Amiri-Bold", size: size) }

    static func deskColor(_ style: PageStyle) -> Color {
        switch style {
        case .coloured: desk
        case .classic: paperLight
        case .night: night
        }
    }
}

/// Every control on the TV: a clear focus that reads across a room (lifted, filled with the mint accent),
/// and the tablet's quieter look otherwise (selected: the dark green container, mint text).
struct FocusStyle: ButtonStyle {
    var cornerRadius: CGFloat = 14
    var selected = false
    var padding = EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
    var fill: Color = .clear

    func makeBody(configuration: Configuration) -> some View {
        FocusBody(configuration: configuration, style: self)
    }

    struct FocusBody: View {
        let configuration: ButtonStyle.Configuration
        let style: FocusStyle
        @Environment(\.isFocused) private var focused

        var body: some View {
            configuration.label
                .padding(style.padding)
                .foregroundStyle(focused ? TV.onPrimary : (style.selected ? TV.primary : TV.onSurface))
                .background(
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .fill(focused ? TV.primary : (style.selected ? TV.selected : style.fill)))
                .scaleEffect(focused ? 1.04 : (configuration.isPressed ? 0.97 : 1))
                .shadow(color: .black.opacity(focused ? 0.45 : 0), radius: 12, y: 6)
                .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}

/// A round icon button of the title bar and the player, as on the tablet.
struct IconButton: View {
    let icon: String
    var label: String = ""
    var selected = false
    var size: CGFloat = 30
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .frame(width: size * 2.1, height: size * 2.1)
        }
        .buttonStyle(FocusStyle(cornerRadius: size * 1.05, selected: selected, padding: EdgeInsets()))
        .accessibilityLabel(label)
    }
}

/// No focus effect at all: for the pages, which show their own focus.
struct BareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

/// The Apple TV app's own text (English, French, Arabic), falling back to the shared table (Localization.swift).
func t(_ english: String) -> String {
    switch Localizer.shared.language {
    case .english: english
    case .french: TVStrings.table[english]?.fr ?? tr(english)
    case .arabic: TVStrings.table[english]?.ar ?? tr(english)
    }
}

func t(_ format: String, _ args: CVarArg...) -> String {
    String(format: t(format), arguments: args)
}

private enum TVStrings {
    static let table: [String: (fr: String, ar: String)] = [
        "Page %d": ("Page %d", "الصفحة %d"),
        "Juz %d": ("Juz' %d", "الجزء %d"),
        "Hizb %d": ("Hizb %d", "الحزب %d"),
        "Ayah %d": ("Verset %d", "الآية %d"),
        "Surahs": ("Sourates", "السور"),
        "Juz": ("Juz'", "الأجزاء"),
        "Bookmarks": ("Signets", "العلامات"),
        "Makki": ("Mecquoise", "مكية"),
        "Madani": ("Médinoise", "مدنية"),
        "%d verses": ("%d versets", "%d آية"),
        "Side menu": ("Menu latéral", "القائمة الجانبية"),
        "Next page": ("Page suivante", "الصفحة التالية"),
        "Previous page": ("Page précédente", "الصفحة السابقة"),
        "Translation & Tafsir": ("Traduction et tafsir", "الترجمة والتفسير"),
        "Mushaf": ("Mushaf", "المصحف"),
        "Bookmark": ("Signet", "علامة"),
        "Two pages": ("Double page", "صفحتان"),
        "Full screen": ("Plein écran", "ملء الشاشة"),
        "Settings": ("Réglages", "الإعدادات"),
        "Help": ("Aide", "المساعدة"),
        "Recitation": ("Récitation", "التلاوة"),
        "Previous verse": ("Verset précédent", "الآية السابقة"),
        "Next verse": ("Verset suivant", "الآية التالية"),
        "Previous surah": ("Sourate précédente", "السورة السابقة"),
        "Next surah": ("Sourate suivante", "السورة التالية"),
        "Click the pages to choose a verse · Play/Pause to recite": (
            "Cliquez sur les pages pour choisir un verset · Lecture/Pause pour réciter",
            "اضغط على الصفحات لاختيار آية · زر التشغيل للتلاوة"),
        "No bookmarks yet. Add one with the bookmark button in the top bar.": (
            "Aucun signet. Ajoutez-en un avec le bouton signet de la barre du haut.",
            "لا توجد علامات بعد. أضف علامة بزر العلامة في الشريط العلوي."),
        "Loading…": ("Chargement…", "جارٍ التحميل…"),
        "Loading the text…": ("Chargement du texte…", "جارٍ تحميل النص…"),
        "Couldn't load the Mushaf. Check the connection.": (
            "Impossible de charger le Mushaf. Vérifiez la connexion.", "تعذّر تحميل المصحف. تحقّق من الاتصال."),
        "Try Again": ("Réessayer", "إعادة المحاولة"),
        "Arabic": ("Arabe", "العربية"),
        "Translation": ("Traduction", "الترجمة"),
        "Both": ("Les deux", "كلاهما"),
        "Tafsir": ("Tafsir", "التفسير"),
        "Recite from this verse": ("Réciter depuis ce verset", "التلاوة من هذه الآية"),
        "Recite from this page": ("Réciter depuis cette page", "التلاوة من هذه الصفحة"),
        "Stop recitation": ("Arrêter la récitation", "إيقاف التلاوة"),
        "Bookmark this page": ("Marquer cette page", "وضع علامة على هذه الصفحة"),
        "Remove bookmark": ("Retirer le signet", "إزالة العلامة"),
        "Cancel": ("Annuler", "إلغاء"),
        "Close": ("Fermer", "إغلاق"),
        "Reciter": ("Récitateur", "القارئ"),
        "Play": ("Lecture", "التشغيل"),
        "This ayah": ("Ce verset", "هذه الآية"),
        "To end of surah": ("Jusqu'à la fin de la sourate", "إلى نهاية السورة"),
        "Continue through Quran": ("Continuer dans le Coran", "متابعة في القرآن"),
        "Repeat each ayah": ("Répéter chaque verset", "تكرار كل آية"),
        "Repeat selection": ("Répéter la sélection", "تكرار المقطع"),
        "Language": ("Langue", "اللغة"),
        "Page style": ("Style des pages", "نمط الصفحات"),
        "Coloured": ("Coloré", "ملوّن"),
        "Classic": ("Classique", "كلاسيكي"),
        "Night": ("Nuit", "ليلي"),
        "Two pages side by side": ("Deux pages côte à côte", "صفحتان متقابلتان"),
        "How to use the remote": ("Utiliser la télécommande", "طريقة استخدام جهاز التحكم"),
        "Opening page": ("Page d'ouverture", "الصفحة الافتتاحية"),
        "Using the Siri Remote": ("Utiliser la télécommande Siri", "استخدام جهاز التحكم Siri"),
        "Got it": ("Compris", "حسنًا"),
        "Begin Reading": ("Commencer la lecture", "ابدأ القراءة"),
        "Continue Reading": ("Continuer la lecture", "متابعة القراءة"),
        "Continue Listening": ("Continuer l'écoute", "متابعة الاستماع"),
        "Start from the Beginning": ("Recommencer au début", "البدء من البداية"),
        "Turn the pages": ("Tourner les pages", "تقليب الصفحات"),
        "On the pages, swipe or press left and right. Left goes forward, as in a printed mushaf.": (
            "Sur les pages, balayez ou appuyez à gauche et à droite. La gauche avance, comme dans un mushaf imprimé.",
            "على الصفحات، اسحب أو اضغط يسارًا ويمينًا. اليسار يتقدّم كما في المصحف المطبوع."),
        "Choose a verse": ("Choisir un verset", "اختيار آية"),
        "Click the pages to select a verse, then swipe left and right to move from verse to verse. Click again for its options: recite from it, translation, tafsir. Back stops selecting.": (
            "Cliquez sur les pages pour sélectionner un verset, puis balayez à gauche et à droite pour passer d'un verset à l'autre. Cliquez encore pour ses options : réciter depuis ce verset, traduction, tafsir. Retour arrête la sélection.",
            "اضغط على الصفحات لتحديد آية، ثم اسحب يسارًا ويمينًا للانتقال بين الآيات. اضغط مرة أخرى لخياراتها: التلاوة منها، الترجمة، التفسير. زر الرجوع ينهي التحديد."),
        "Listen": ("Écouter", "الاستماع"),
        "Play/Pause recites from the page, or from the selected verse, and pauses. The verse being recited is highlighted and the pages turn with it.": (
            "Lecture/Pause récite depuis la page, ou depuis le verset sélectionné, et met en pause. Le verset récité est surligné et les pages tournent avec lui.",
            "زر التشغيل/الإيقاف يتلو من الصفحة أو من الآية المحددة ويوقف التلاوة مؤقتًا. تُظلَّل الآية المتلوّة وتتقلّب الصفحات معها."),
        "The top bar and the side menu": ("La barre du haut et le menu latéral", "الشريط العلوي والقائمة الجانبية"),
        "Swipe up for the top bar: pages, translation and tafsir, bookmark, two pages, full screen, settings and this help. From its first button, swipe down into the side menu: surahs, juz and bookmarks.": (
            "Balayez vers le haut pour la barre du haut : pages, traduction et tafsir, signet, double page, plein écran, réglages et cette aide. Depuis son premier bouton, balayez vers le bas dans le menu latéral : sourates, juz' et signets.",
            "اسحب للأعلى للشريط العلوي: الصفحات، الترجمة والتفسير، العلامة، الصفحتان، ملء الشاشة، الإعدادات وهذه المساعدة. ومن زره الأول اسحب للأسفل إلى القائمة الجانبية: السور والأجزاء والعلامات."),
        "The player": ("Le lecteur", "المشغّل"),
        "Swipe down from the pages for the player: previous and next verse, play, and the recitation options (reciter, range and repeats).": (
            "Balayez vers le bas depuis les pages pour le lecteur : verset précédent et suivant, lecture, et les options de récitation (récitateur, étendue et répétitions).",
            "اسحب للأسفل من الصفحات للمشغّل: الآية السابقة والتالية، التشغيل، وخيارات التلاوة (القارئ والنطاق والتكرار)."),
        "Back": ("Retour", "الرجوع"),
        "Back closes a panel or a menu, and leaves full screen. On the pages, it returns to the Apple TV Home screen.": (
            "Retour ferme un panneau ou un menu, et quitte le plein écran. Sur les pages, il ramène à l'écran d'accueil de l'Apple TV.",
            "زر الرجوع يغلق اللوحة أو القائمة ويخرج من ملء الشاشة. وعلى الصفحات يعود إلى الشاشة الرئيسية لجهاز Apple TV."),
        "◀ ▶ turn the pages · Click: choose a verse · ▲ top bar · ▼ player": (
            "◀ ▶ tourner les pages · Clic : choisir un verset · ▲ barre du haut · ▼ lecteur",
            "◀ ▶ تقليب الصفحات · ضغطة: اختيار آية · ▲ الشريط العلوي · ▼ المشغّل"),
        "◀ ▶ move between verses · Click: options · Back: done": (
            "◀ ▶ passer d'un verset à l'autre · Clic : options · Retour : terminer",
            "◀ ▶ التنقل بين الآيات · ضغطة: الخيارات · الرجوع: إنهاء"),
        "Back: leave full screen": ("Retour : quitter le plein écran", "الرجوع: الخروج من ملء الشاشة"),
        "Version %@": ("Version %@", "الإصدار %@"),
    ]
}
