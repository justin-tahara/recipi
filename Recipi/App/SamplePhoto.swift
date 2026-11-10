#if DEBUG
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Food "photos" drawn in code for the sample library and the screenshot
/// fixture page: a dish on a table with a cloth beside it. Nothing is
/// copied from a website, and the same style always draws the same picture.
///
/// Plain Core Graphics, so the fixture web stub can draw one off the main
/// thread.
enum SamplePhoto {
    static let width = 1_200
    static let height = 900

    struct RGB: Sendable, Hashable {
        var red: Double
        var green: Double
        var blue: Double

        init(_ hex: UInt32) {
            red = Double((hex >> 16) & 0xFF) / 255
            green = Double((hex >> 8) & 0xFF) / 255
            blue = Double(hex & 0xFF) / 255
        }

        /// The same hue, darker below 1 and lighter above.
        func scaled(_ factor: Double) -> RGB {
            var color = self
            color.red = min(1, red * factor)
            color.green = min(1, green * factor)
            color.blue = min(1, blue * factor)
            return color
        }

        func cgColor(alpha: Double = 1) -> CGColor {
            CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        }
    }

    enum Dish: Sendable {
        case plate
        case bowl
        /// A loaf and two slices on a board.
        case loaf
    }

    struct Style: Sendable {
        var dish: Dish
        var table: RGB
        var cloth: RGB
        /// The main food color.
        var food: RGB
        /// Something under the food, like rice or a tortilla.
        var base: RGB?
        /// Small bits scattered on top. For a loaf, the first is the bits
        /// and the second the crumb.
        var garnish: [RGB]
        /// Eggs nestled in the food, for shakshuka.
        var eggs = 0
        var seed: UInt64
    }

    /// The picture as a JPEG, or nil if it couldn't be drawn.
    static func jpeg(_ style: Style) -> Data? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { return nil }
        // Draw with the origin at the top left. Shadow offsets aren't
        // flipped by this, so a negative height drops a shadow downward.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        var random = SeededRandom(seed: style.seed)
        drawTable(style, in: context, random: &random)
        drawCloth(style, in: context)
        switch style.dish {
        case .plate, .bowl:
            drawPlate(style, in: context, random: &random)
        case .loaf:
            drawLoaf(style, in: context, random: &random)
        }

        guard let image = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    // MARK: - Drawing

    private static func drawTable(_ style: Style, in context: CGContext, random: inout SeededRandom) {
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(style.table.cgColor())
        context.fill(bounds)

        // Wood grain.
        context.setLineCap(.round)
        for _ in 0..<22 {
            let y = random.value(0...Double(height))
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -20, y: y))
            path.addCurve(
                to: CGPoint(x: CGFloat(width) + 20, y: y + random.value(-30...30)),
                control1: CGPoint(x: 400, y: y + random.value(-25...25)),
                control2: CGPoint(x: 800, y: y + random.value(-25...25))
            )
            context.addPath(path)
            context.setStrokeColor(CGColor(gray: 0, alpha: random.value(0.025...0.06)))
            context.setLineWidth(random.value(1.5...5))
            context.strokePath()
        }

        // Light from the top left.
        let colors = [CGColor(gray: 1, alpha: 0.14), CGColor(gray: 0, alpha: 0.12)] as CFArray
        if let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        }
    }

    private static func drawCloth(_ style: Style, in context: CGContext) {
        context.saveGState()
        context.translateBy(x: 210, y: 720)
        context.rotate(by: -0.22)
        let rect = CGRect(x: -300, y: -200, width: 600, height: 400)
        context.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: CGColor(gray: 0, alpha: 0.18))
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 14, cornerHeight: 14, transform: nil))
        context.setFillColor(style.cloth.cgColor())
        context.fillPath()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        // Two stripes along one edge.
        context.setFillColor(CGColor(gray: 1, alpha: 0.45))
        context.fill(CGRect(x: -300, y: -150, width: 600, height: 10))
        context.fill(CGRect(x: -300, y: -128, width: 600, height: 5))
        context.restoreGState()
    }

    private static func drawPlate(_ style: Style, in context: CGContext, random: inout SeededRandom) {
        let center = CGPoint(x: 600, y: 450)
        let isBowl = style.dish == .bowl
        let plateRadius: CGFloat = isBowl ? 320 : 345

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -24), blur: 48, color: CGColor(gray: 0, alpha: 0.3))
        context.setFillColor(RGB(0xF8F5EF).cgColor())
        context.fillEllipse(in: circle(center, plateRadius))
        context.restoreGState()

        context.setStrokeColor(CGColor(gray: 0, alpha: 0.07))
        context.setLineWidth(4)
        context.strokeEllipse(in: circle(center, plateRadius * 0.78))

        var foodRadius = plateRadius * 0.6
        if isBowl {
            context.setFillColor(RGB(0xECE5D9).cgColor())
            context.fillEllipse(in: circle(center, plateRadius * 0.86))
            foodRadius = plateRadius * 0.8
        }

        if let base = style.base {
            fill(blob(center, radius: foodRadius * 1.12, wobble: 0.08, random: &random), base.cgColor(), in: context)
            foodRadius *= 0.72
        }
        let foodCenter = style.base == nil ? center : CGPoint(x: center.x + 18, y: center.y - 10)
        fill(blob(foodCenter, radius: foodRadius, wobble: isBowl ? 0.02 : 0.1, random: &random), style.food.cgColor(), in: context)
        // A soft shine.
        let shine = CGPoint(x: foodCenter.x - foodRadius * 0.25, y: foodCenter.y - foodRadius * 0.25)
        fill(blob(shine, radius: foodRadius * 0.45, wobble: 0.1, random: &random), CGColor(gray: 1, alpha: 0.12), in: context)

        if style.eggs > 0 {
            for index in 0..<style.eggs {
                let angle = CGFloat(index) / CGFloat(style.eggs) * 2 * .pi + 0.4
                let egg = CGPoint(
                    x: foodCenter.x + foodRadius * 0.48 * cos(angle),
                    y: foodCenter.y + foodRadius * 0.48 * sin(angle)
                )
                fill(blob(egg, radius: 62, wobble: 0.12, random: &random), RGB(0xFBF8F1).cgColor(), in: context)
                context.setFillColor(RGB(0xF2B33D).cgColor())
                context.fillEllipse(in: circle(CGPoint(x: egg.x + 4, y: egg.y + 2), 26))
                context.setFillColor(CGColor(gray: 1, alpha: 0.35))
                context.fillEllipse(in: circle(CGPoint(x: egg.x - 4, y: egg.y - 6), 7))
            }
        }

        scatter(style.garnish, count: 40, around: foodCenter, radius: foodRadius * 0.85, size: 7...19, in: context, random: &random)
    }

    private static func drawLoaf(_ style: Style, in context: CGContext, random: inout SeededRandom) {
        let board = CGRect(x: 110, y: 230, width: 980, height: 500)
        let boardPath = CGPath(roundedRect: board, cornerWidth: 40, cornerHeight: 40, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -20), blur: 40, color: CGColor(gray: 0, alpha: 0.28))
        context.addPath(boardPath)
        context.setFillColor(RGB(0xC7976A).cgColor())
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(boardPath)
        context.clip()
        for _ in 0..<10 {
            let y = random.value(Double(board.minY + 20)...Double(board.maxY - 20))
            context.move(to: CGPoint(x: board.minX, y: y))
            context.addLine(to: CGPoint(x: board.maxX, y: y + random.value(-8...8)))
            context.setStrokeColor(CGColor(gray: 0, alpha: 0.06))
            context.setLineWidth(random.value(2...4))
            context.strokePath()
        }
        context.restoreGState()

        let bits = style.garnish.first ?? style.food.scaled(0.6)
        let crumb = style.garnish.dropFirst().first ?? style.food.scaled(1.4)

        let loaf = CGRect(x: 200, y: 310, width: 560, height: 300)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: CGColor(gray: 0, alpha: 0.3))
        context.addPath(CGPath(roundedRect: loaf, cornerWidth: 120, cornerHeight: 120, transform: nil))
        context.setFillColor(style.food.cgColor())
        context.fillPath()
        context.restoreGState()
        // The split along the top, and a shine above it.
        context.setFillColor(style.food.scaled(0.75).cgColor())
        context.fillEllipse(in: CGRect(x: 260, y: 405, width: 440, height: 80))
        context.setFillColor(CGColor(gray: 1, alpha: 0.12))
        context.fillEllipse(in: CGRect(x: 240, y: 330, width: 480, height: 80))
        scatter([bits], count: 14, around: CGPoint(x: 480, y: 450), radius: 200, size: 8...15, in: context, random: &random)

        for (index, origin) in [CGPoint(x: 800, y: 330), CGPoint(x: 880, y: 360)].enumerated() {
            context.saveGState()
            context.translateBy(x: origin.x, y: origin.y)
            context.rotate(by: 0.1 + CGFloat(index) * 0.08)
            let slice = CGRect(x: 0, y: 0, width: 150, height: 280)
            context.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: CGColor(gray: 0, alpha: 0.25))
            context.addPath(CGPath(roundedRect: slice, cornerWidth: 46, cornerHeight: 46, transform: nil))
            context.setFillColor(style.food.cgColor())
            context.fillPath()
            context.setShadow(offset: .zero, blur: 0, color: nil)
            context.addPath(CGPath(roundedRect: slice.insetBy(dx: 14, dy: 14), cornerWidth: 34, cornerHeight: 34, transform: nil))
            context.setFillColor(crumb.cgColor())
            context.fillPath()
            scatter([bits], count: 7, around: CGPoint(x: 75, y: 140), radius: 50, size: 6...10, in: context, random: &random)
            context.restoreGState()
        }
    }

    // MARK: - Shapes

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    private static func fill(_ path: CGPath, _ color: CGColor, in context: CGContext) {
        context.addPath(path)
        context.setFillColor(color)
        context.fillPath()
    }

    /// A rounded, slightly uneven shape, like food on a plate.
    private static func blob(_ center: CGPoint, radius: CGFloat, wobble: Double, random: inout SeededRandom) -> CGPath {
        let count = 14
        var points: [CGPoint] = []
        for index in 0..<count {
            let angle = CGFloat(index) / CGFloat(count) * 2 * .pi
            let distance = radius * random.value((1 - wobble)...(1 + wobble * 0.3))
            points.append(CGPoint(x: center.x + distance * cos(angle), y: center.y + distance * sin(angle)))
        }
        func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        let path = CGMutablePath()
        path.move(to: midpoint(points[count - 1], points[0]))
        for index in 0..<count {
            path.addQuadCurve(to: midpoint(points[index], points[(index + 1) % count]), control: points[index])
        }
        path.closeSubpath()
        return path
    }

    /// Small round and leaf-shaped bits scattered in a circle.
    private static func scatter(
        _ colors: [RGB],
        count: Int,
        around center: CGPoint,
        radius: CGFloat,
        size: ClosedRange<Double>,
        in context: CGContext,
        random: inout SeededRandom
    ) {
        guard !colors.isEmpty else { return }
        for index in 0..<count {
            let angle = random.value(0...(2 * Double.pi))
            let distance = radius * random.value(0...1).squareRoot()
            let point = CGPoint(x: center.x + distance * cos(angle), y: center.y + distance * sin(angle))
            let length = random.value(size)
            context.saveGState()
            context.translateBy(x: point.x, y: point.y)
            context.rotate(by: random.value(0...(2 * Double.pi)))
            context.setFillColor(colors[index % colors.count].cgColor())
            let rect = index % 3 == 0
                ? CGRect(x: -length, y: -length / 2, width: length * 2, height: length)
                : CGRect(x: -length / 2, y: -length / 2, width: length, height: length)
            context.fillEllipse(in: rect)
            context.restoreGState()
        }
    }
}

/// SplitMix64: the same seed gives the same numbers on every run, unlike
/// the system generator.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func value(_ range: ClosedRange<Double>) -> CGFloat {
        CGFloat(Double.random(in: range, using: &self))
    }
}
#endif
