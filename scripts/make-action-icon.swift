import AppKit
// Usage: xcrun swift scripts/make-action-icon.swift AddBorderAction/Assets.xcassets/AppIcon.appiconset/ActionIcon-1024.png

// Redraws the multiborder app icon's seven squares as a black template glyph on a transparent
// 1024px canvas. Coordinates are measured from App-Icon-1024x1024@1x.png (top-left origin).
let out = CommandLine.arguments[1]
let side = 191.0, stroke = 25.0
let origins: [(Double, Double)] = [
    (175, 195), (175, 416), (175, 637),   // left column
    (415, 302),                           // middle, between the first two rows
    (656, 195), (656, 416), (656, 637),   // right column
]
// The glyph spans x 175–847, y 195–828; scale it to 760px wide and center it.
let (minX, maxX, minY, maxY) = (175.0, 847.0, 195.0, 828.0)
let scale = 760.0 / (maxX - minX)
let offsetX = (1024 - (maxX - minX) * scale) / 2, offsetY = (1024 - (maxY - minY) * scale) / 2
let thickStroke = stroke * 1.6   // in the original's units; thicker so it reads at list size

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.black.setFill()
for (x, y) in origins {
    let outer = NSRect(x: offsetX + (x - minX) * scale,
                       y: Double(size) - (offsetY + (y - minY) * scale) - side * scale,  // flip to bottom-left origin
                       width: side * scale, height: side * scale)
    let path = NSBezierPath(rect: outer)
    path.append(NSBezierPath(rect: outer.insetBy(dx: thickStroke * scale, dy: thickStroke * scale)))
    path.windingRule = .evenOdd
    path.fill()
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
