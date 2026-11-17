// Prints the window number of Mus'haf's main window (for screencapture -l).
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let windows = list.filter {
    (($0[kCGWindowOwnerName as String] as? String) ?? "").localizedCaseInsensitiveContains("haf")
        && ($0[kCGWindowLayer as String] as? Int) == 0
}
let biggest = windows.max {
    let a = $0[kCGWindowBounds as String] as? [String: Double] ?? [:], b = $1[kCGWindowBounds as String] as? [String: Double] ?? [:]
    return (a["Width"] ?? 0) * (a["Height"] ?? 0) < (b["Width"] ?? 0) * (b["Height"] ?? 0)
}
if let n = biggest?[kCGWindowNumber as String] { print(n) } else { exit(1) }
