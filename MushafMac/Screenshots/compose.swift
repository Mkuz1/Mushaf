// compose.swift <window.png> <out.png> <caption> : the window capture on Mus'haf's green, with the caption above,
// at 2880 x 1800, or 1440 x 900 for a small capture (both Mac App Store sizes, no upscaling blur).
// AppKit lays out Arabic captions right to left.
import AppKit

let a = CommandLine.arguments
guard a.count == 4, let shot = NSImage(contentsOfFile: a[1]), let rep = shot.representations.first else { exit(1) }
let k = rep.pixelsWide >= 1800 ? 2.0 : 1.0
let W = 1440.0 * k, H = 900.0 * k
let canvas = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
NSGradient(starting: NSColor(red: 0.05, green: 0.24, blue: 0.18, alpha: 1),
           ending: NSColor(red: 0.02, green: 0.12, blue: 0.09, alpha: 1))!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

let para = NSMutableParagraphStyle()
para.alignment = .center
let caption = NSAttributedString(string: a[3], attributes: [
    .font: NSFont.systemFont(ofSize: 46 * k, weight: .semibold),
    .foregroundColor: NSColor(red: 0.93, green: 0.82, blue: 0.55, alpha: 1),
    .paragraphStyle: para])
caption.draw(in: NSRect(x: 60 * k, y: H - 125 * k, width: W - 120 * k, height: 75 * k))

// The window, as large as fits under the caption, with a soft shadow.
let px = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
let box = CGSize(width: W - 120 * k, height: H - 170 * k)
let s = min(box.width / px.width, box.height / px.height)
let size = CGSize(width: px.width * s, height: px.height * s)
let rect = NSRect(x: (W - size.width) / 2, y: (H - 150 * k - size.height) / 2 + 10 * k, width: size.width, height: size.height)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
shadow.shadowBlurRadius = 30 * k
shadow.shadowOffset = NSSize(width: 0, height: -10 * k)
shadow.set()
NSGraphicsContext.current?.imageInterpolation = .high
shot.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try! canvas.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
