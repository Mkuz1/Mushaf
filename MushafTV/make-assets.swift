// make-assets.swift <icon.png> <Assets.xcassets>: the Apple TV asset catalog from Mus'haf's square icon:
// the layered app icons (front: the icon; back: Mus'haf's green), the Top Shelf images and the launch image.
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let icon = NSImage(contentsOfFile: args[1]) else { fatalError("usage: make-assets <icon.png> <dir>") }
let root = URL(fileURLWithPath: args[2])
let fm = FileManager.default
try? fm.removeItem(at: root)
let info: [String: Any] = ["author": "xcode", "version": 1]

func write(_ json: [String: Any], _ dir: URL) {
    try! fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let data = try! JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    try! data.write(to: dir.appendingPathComponent("Contents.json"))
}

/// Draws a w x h PNG: the green background (unless transparent) and, if iconScale > 0, the icon centred at that
/// fraction of the height, with "Mus'haf" beside it when titled.
func png(_ url: URL, _ w: Int, _ h: Int, background: Bool, iconScale: CGFloat, titled: Bool = false) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let W = CGFloat(w), H = CGFloat(h)
    if background {
        NSGradient(starting: NSColor(red: 0.07, green: 0.30, blue: 0.22, alpha: 1),
                   ending: NSColor(red: 0.02, green: 0.12, blue: 0.09, alpha: 1))!
            .draw(in: NSRect(x: 0, y: 0, width: W, height: H), relativeCenterPosition: .zero)
    }
    if iconScale > 0 {
        let side = H * iconScale
        var x = (W - side) / 2
        if titled {
            let title = NSAttributedString(string: "Mus'haf", attributes: [
                .font: NSFont.systemFont(ofSize: H * 0.2, weight: .semibold),
                .foregroundColor: NSColor(red: 0.93, green: 0.82, blue: 0.55, alpha: 1)])
            let t = title.size()
            let gap = H * 0.08
            x = (W - side - gap - t.width) / 2
            title.draw(at: NSPoint(x: x + side + gap, y: (H - t.height) / 2))
        }
        let rect = NSRect(x: x, y: (H - side) / 2, width: side, height: side)
        NSGraphicsContext.current?.imageInterpolation = .high
        let clip = NSBezierPath(roundedRect: rect, xRadius: side * 0.18, yRadius: side * 0.18)
        clip.addClip()
        icon.draw(in: rect)
    }
    NSGraphicsContext.restoreGraphicsState()
    try! fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

write(["info": info], root)
let brand = root.appendingPathComponent("App Icon & Top Shelf Image.brandassets")
write(["info": info, "assets": [
    ["filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"],
    ["filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"],
    ["filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"],
    ["filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"],
]], brand)

/// A layered icon: Front (the icon, transparent around it) over Back (green).
func stack(_ name: String, _ w: Int, _ h: Int, scales: [Int]) {
    let dir = brand.appendingPathComponent("\(name).imagestack")
    write(["info": info, "layers": [["filename": "Front.imagestacklayer"], ["filename": "Back.imagestacklayer"]]], dir)
    for (layer, isBack) in [("Front", false), ("Back", true)] {
        let l = dir.appendingPathComponent("\(layer).imagestacklayer")
        write(["info": info], l)
        let set = l.appendingPathComponent("Content.imageset")
        var images: [[String: Any]] = []
        for s in scales {
            let file = "\(layer.lowercased())@\(s)x.png"
            png(set.appendingPathComponent(file), w * s, h * s, background: isBack, iconScale: isBack ? 0 : 0.78)
            images.append(["idiom": "tv", "filename": file, "scale": "\(s)x"])
        }
        write(["info": info, "images": images], set)
    }
}
stack("App Icon", 400, 240, scales: [1, 2])
stack("App Icon - App Store", 1280, 768, scales: [1])

for (name, w, h) in [("Top Shelf Image", 1920, 720), ("Top Shelf Image Wide", 2320, 720)] {
    let set = brand.appendingPathComponent("\(name).imageset")
    var images: [[String: Any]] = []
    for s in [1, 2] {
        let file = "shelf@\(s)x.png"
        png(set.appendingPathComponent(file), w * s, h * s, background: true, iconScale: 0.55, titled: true)
        images.append(["idiom": "tv", "filename": file, "scale": "\(s)x"])
    }
    write(["info": info, "images": images], set)
}

let launch = root.appendingPathComponent("LaunchImage.launchimage")
var launchImages: [[String: Any]] = []
for s in [1, 2] {
    let file = "launch@\(s)x.png"
    png(launch.appendingPathComponent(file), 1920 * s, 1080 * s, background: true, iconScale: 0.3)
    launchImages.append(["orientation": "landscape", "idiom": "tv", "extent": "full-screen",
                         "minimum-system-version": "11.0", "filename": file, "scale": "\(s)x"])
}
write(["info": info, "images": launchImages], launch)
print("Assets written to \(root.path)")
