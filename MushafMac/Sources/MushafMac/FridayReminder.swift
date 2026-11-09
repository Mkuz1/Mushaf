import Foundation
import UserNotifications

private let reminderID = "friday-kahf"

/// A weekly notification on Friday to read Surat Al-Kahf, as in the Android, iPhone and Windows apps. macOS
/// shows it at its time every week, with the app closed; clicking it opens the app at Al-Kahf.
@MainActor
@Observable
final class FridayReminder {
    /// On by default: the first launch asks macOS for permission (see start()).
    var enabled = UserDefaults.standard.object(forKey: "kahfReminder") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "kahfReminder")
            Task { await apply(ask: enabled) }
        }
    }

    /// The time on Friday, in the Mac's time zone.
    var time: Date = {
        let d = UserDefaults.standard
        return Calendar.current.date(from: DateComponents(
            hour: d.object(forKey: "kahfHour") as? Int ?? 9, minute: d.object(forKey: "kahfMinute") as? Int ?? 0)) ?? Date()
    }() {
        didSet {
            let c = Calendar.current.dateComponents([.hour, .minute], from: time)
            UserDefaults.standard.set(c.hour, forKey: "kahfHour")
            UserDefaults.standard.set(c.minute, forKey: "kahfMinute")
            Task { await apply() }
        }
    }

    /// Set by the app: opens Al-Kahf when the notification is clicked.
    var onOpen: (() -> Void)?

    private let delegate = Delegate()

    init() {
        delegate.open = { [weak self] in self?.onOpen?() }
        UNUserNotificationCenter.current().delegate = delegate
    }

    /// At launch: the first time, asks for permission and schedules it; later, schedules it again (in the
    /// language now in use).
    func start() async {
        let firstTime = !UserDefaults.standard.bool(forKey: "kahfAsked")
        UserDefaults.standard.set(true, forKey: "kahfAsked")
        await apply(ask: firstTime && enabled)
    }

    /// Replaces the scheduled reminder; [ask] requests permission first (turning it off if refused).
    func apply(ask: Bool = false) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        guard enabled else { return }
        if ask {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            if !granted {
                enabled = false
                return
            }
        }
        let content = UNMutableNotificationContent()
        content.title = tr("Friday: Surat Al-Kahf")
        content.body = tr("“Whoever reads Surat Al-Kahf on Friday will have a light shining for them between the two Fridays.”")
        content.sound = .default
        var when = Calendar.current.dateComponents([.hour, .minute], from: time)
        when.weekday = 6  // Friday (Sunday is 1)
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
    }

    /// Shows the reminder while the app is open too, and opens Al-Kahf when it is clicked.
    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        var open: (@MainActor () -> Void)?

        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
            async -> UNNotificationPresentationOptions { [.banner, .sound] }

        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
            guard response.notification.request.identifier == reminderID else { return }
            let open = self.open
            await MainActor.run { open?() }
        }
    }
}
