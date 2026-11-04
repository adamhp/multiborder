// Writes the HDR test photos in multiborderTests/: a 400×300 gray gradient from black at the left edge
// to 4× SDR white at the right, saved as JPEG with an ISO 21496-1 gain map, upright and with EXIF orientation 6.
//
// The iOS Simulator can't encode gain maps from HDR images, so the photos are made on a Mac and checked in:
//   swift scripts/make-hdr-fixtures.swift multiborderTests

import Foundation
import ImageIO
import UniformTypeIdentifiers

let directory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let width = 400, height = 300
let space = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 32, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue
                            | CGBitmapInfo.byteOrder32Little.rawValue)!
let pixels = context.data!.assumingMemoryBound(to: Float.self)
let rowFloats = context.bytesPerRow / 4
for y in 0..<height {
    for x in 0..<width {
        let value = Float(x) / Float(width - 1) * 4
        let index = y * rowFloats + x * 4
        (pixels[index], pixels[index + 1], pixels[index + 2], pixels[index + 3]) = (value, value, value, 1)
    }
}
let image = CGImageCreateCopyWithContentHeadroom(4, context.makeImage()!)!

for (name, orientation) in [("hdr-gradient.jpg", 1), ("hdr-gradient-orientation6.jpg", 6)] {
    let output = NSMutableData()
    let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, [
        kCGImageDestinationEncodeRequest: kCGImageDestinationEncodeToISOGainmap,
        kCGImagePropertyOrientation: orientation,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { fatalError("Couldn't encode \(name)") }
    try! (output as Data).write(to: directory.appendingPathComponent(name))
    print("Wrote", name)
}
