#!/usr/bin/env swift
//
// Renders the menu bar template icon from the app icon.
//
// The glyph is not redrawn here. The app icon is a solid #FF674D tile with one
// white glyph on it, so the glyph is recovered by reading how white each pixel
// is and using that as the alpha of a black image. Tracing the shape by hand
// would let the two icons drift apart, which is exactly what a menu bar icon
// must not do — it sits next to the Dock icon all day.
//
// Whiteness is read off the blue channel: the tile and the glyph share a red
// channel of 255, so red carries no information, and blue separates them the
// furthest (0.302 against 1.0).
//
// Pixels are read and written through raw CoreGraphics buffers rather than
// NSBitmapImageRep's colorAt/setColor, which log a colourspace warning per
// pixel and turn a 1024x1024 pass into tens of megabytes of noise.
//
// Usage: swift scripts/generate_menubar_icon.swift
//   [<AppIcon source png>] [<MenuBarIcon.imageset destination>]

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
let sourcePath = arguments.count > 1
    ? arguments[1]
    : "LinguaDock/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
let destinationPath = arguments.count > 2
    ? arguments[2]
    : "LinguaDock/Resources/Assets.xcassets/MenuBarIcon.imageset"

/// The menu bar slot is 18pt tall and the glyph needs a little air around it,
/// so it is fitted into this fraction of the canvas rather than filling it.
let glyphFillRatio = 0.86

let outputs = [
    (name: "menubar.png", size: 18),
    (name: "menubar@2x.png", size: 36),
    (name: "menubar@3x.png", size: 54),
]

/// Blue channel of the phpz.xyz app icon family's tile colour, #FF674D.
let tileBlue = 77.0 / 255

struct GeneratorError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

/// An RGBA8 buffer, so pixels can be read and written as plain bytes.
func makeContext(width: Int, height: Int) throws -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw GeneratorError("cannot allocate a \(width)x\(height) buffer") }
    return context
}

/// The app icon's glyph as a black image with a soft alpha edge, cropped to the
/// glyph's bounding box.
func extractGlyph(from path: String) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw GeneratorError("cannot read the app icon at \(path)") }

    let width = image.width
    let height = image.height
    let readContext = try makeContext(width: width, height: height)
    readContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let pixels = readContext.data else {
        throw GeneratorError("cannot address the app icon's pixels")
    }
    let bytes = pixels.bindMemory(to: UInt8.self, capacity: width * height * 4)

    var alpha = [Double](repeating: 0, count: width * height)
    var minX = width, maxX = -1, minY = height, maxY = -1

    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            // Only the tile's interior is fully opaque; its antialiased corners
            // carry premultiplied values that would read as false glyph pixels.
            guard bytes[offset + 3] == 255 else { continue }

            // 0 on the tile, 1 on the glyph, in between on an antialiased edge.
            let whiteness = (Double(bytes[offset + 2]) / 255 - tileBlue) / (1 - tileBlue)
            let clamped = min(max(whiteness, 0), 1)
            guard clamped > 0.01 else { continue }

            alpha[y * width + x] = clamped
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }

    guard maxX >= 0 else { throw GeneratorError("found no glyph pixels in \(path)") }

    let glyphWidth = maxX - minX + 1
    let glyphHeight = maxY - minY + 1
    let writeContext = try makeContext(width: glyphWidth, height: glyphHeight)
    guard let out = writeContext.data else {
        throw GeneratorError("cannot address the glyph buffer")
    }
    let outBytes = out.bindMemory(to: UInt8.self, capacity: glyphWidth * glyphHeight * 4)

    for y in 0..<glyphHeight {
        for x in 0..<glyphWidth {
            let value = alpha[(minY + y) * width + (minX + x)]
            let offset = (y * glyphWidth + x) * 4
            // Premultiplied black: the colour channels stay at zero whatever the
            // alpha, so only the alpha byte carries the shape.
            outBytes[offset] = 0
            outBytes[offset + 1] = 0
            outBytes[offset + 2] = 0
            outBytes[offset + 3] = UInt8((value * 255).rounded())
        }
    }

    guard let glyph = writeContext.makeImage() else {
        throw GeneratorError("cannot build the glyph image")
    }
    print("glyph \(glyphWidth)x\(glyphHeight) extracted from \(path)")
    return glyph
}

/// The glyph centred on a square canvas at the requested pixel size.
func renderMenuBarIcon(glyph: CGImage, size: Int) throws -> CGImage {
    let context = try makeContext(width: size, height: size)
    context.interpolationQuality = .high

    // Fit, don't stretch: the glyph's own aspect ratio is part of the shape.
    let available = Double(size) * glyphFillRatio
    let scale = min(available / Double(glyph.width), available / Double(glyph.height))
    let drawnWidth = Double(glyph.width) * scale
    let drawnHeight = Double(glyph.height) * scale
    context.draw(glyph, in: CGRect(
        x: (Double(size) - drawnWidth) / 2,
        y: (Double(size) - drawnHeight) / 2,
        width: drawnWidth, height: drawnHeight
    ))

    guard let image = context.makeImage() else {
        throw GeneratorError("cannot build the \(size)x\(size) image")
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { throw GeneratorError("cannot write \(url.lastPathComponent)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw GeneratorError("cannot encode \(url.lastPathComponent)")
    }
}

let contentsJSON = """
{
  "images" : [
    { "idiom" : "universal", "filename" : "menubar.png", "scale" : "1x" },
    { "idiom" : "universal", "filename" : "menubar@2x.png", "scale" : "2x" },
    { "idiom" : "universal", "filename" : "menubar@3x.png", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "template-rendering-intent" : "template" }
}

"""

let glyph = try extractGlyph(from: sourcePath)

let destination = URL(fileURLWithPath: destinationPath)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

for output in outputs {
    let url = destination.appendingPathComponent(output.name)
    try writePNG(try renderMenuBarIcon(glyph: glyph, size: output.size), to: url)
    let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
    print("wrote \(output.name) (\(output.size)x\(output.size), \(size) bytes)")
}

try contentsJSON.write(
    to: destination.appendingPathComponent("Contents.json"),
    atomically: true, encoding: .utf8
)
print("wrote Contents.json")
