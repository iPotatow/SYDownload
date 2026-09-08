import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    fputs("usage: create_dmg_background.swift OUTPUT.png\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let logicalSize = CGSize(width: 540, height: 380)
let scale: CGFloat = 2
let pixelWidth = Int(logicalSize.width * scale)
let pixelHeight = Int(logicalSize.height * scale)
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let context = CGContext(
    data: nil,
    width: pixelWidth,
    height: pixelHeight,
    bitsPerComponent: 8,
    bytesPerRow: pixelWidth * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("could not create bitmap context\n", stderr)
    exit(1)
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func stroke(
    from start: CGPoint,
    to end: CGPoint,
    width: CGFloat,
    color: CGColor
) {
    context.saveGState()
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: start)
    context.addLine(to: end)
    context.strokePath()
    context.restoreGState()
}

func drawPencilArrow() {
    let graphite = (red: CGFloat(0.20), green: CGFloat(0.21), blue: CGFloat(0.22))

    // Several slightly offset graphite strokes create the rough, hand-drawn
    // pencil texture without relying on a raster asset.
    let shaftStrokes: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (218, 188.1, 321, 190.0, 3.2),
        (220, 189.7, 322, 190.8, 2.8),
        (217, 191.1, 321, 191.7, 3.0),
        (219, 192.5, 320, 192.2, 2.5),
        (221, 186.9, 319, 188.5, 2.2),
        (216, 190.4, 321, 189.1, 1.8),
        (222, 193.1, 318, 191.2, 1.5)
    ]

    for (index, item) in shaftStrokes.enumerated() {
        let alpha = CGFloat(0.48 + Double(index % 4) * 0.08)
        stroke(
            from: CGPoint(x: item.0, y: item.1),
            to: CGPoint(x: item.2, y: item.3),
            width: item.4,
            color: color(graphite.red, graphite.green, graphite.blue, alpha)
        )
    }

    let upperHead: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (296, 211, 323, 190, 3.6),
        (298, 208, 322, 189, 3.0),
        (294, 213, 321, 191, 2.4),
        (300, 207, 324, 190, 1.8)
    ]
    let lowerHead: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (296, 169, 323, 190, 3.6),
        (298, 172, 322, 191, 3.0),
        (294, 167, 321, 189, 2.4),
        (300, 173, 324, 190, 1.8)
    ]

    for (index, item) in (upperHead + lowerHead).enumerated() {
        let alpha = CGFloat(0.54 + Double(index % 4) * 0.07)
        stroke(
            from: CGPoint(x: item.0, y: item.1),
            to: CGPoint(x: item.2, y: item.3),
            width: item.4,
            color: color(graphite.red, graphite.green, graphite.blue, alpha)
        )
    }
}

context.scaleBy(x: scale, y: scale)
context.setFillColor(color(0.97, 0.98, 1.0))
context.fill(CGRect(origin: .zero, size: logicalSize))
drawPencilArrow()

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      ) else {
    fputs("could not create PNG destination\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("could not write PNG\n", stderr)
    exit(1)
}
