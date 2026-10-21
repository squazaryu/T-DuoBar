import AppKit
import CoreText

/// Typography in final view points, independent of the ring's 32-point canvas.
struct DuoBatteryPercentageTypography {
    private static let referenceFont: NSFont = {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        return font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 11) } ?? font
    }()
    private final class ShapedDigits {
        let advance: CGFloat
        let ink: CGRect
        init(value: Int, font: NSFont) {
            let text = NSAttributedString(string: String(value), attributes: [.font: font])
            let line = CTLineCreateWithAttributedString(text)
            advance = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            ink = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
        }
    }
    private static let shapedDigits: NSCache<NSString, ShapedDigits> = {
        let cache = NSCache<NSString, ShapedDigits>()
        cache.countLimit = 512
        return cache
    }()

    let density: CGFloat
    let font: NSFont
    let digitWidth: CGFloat
    let digitInkWidth: CGFloat
    let digitInkLeft: CGFloat
    let boltSize: CGFloat
    let boltWidth: CGFloat
    let spacing: CGFloat
    let capHeight: CGFloat
    let textHeight: CGFloat
    let capTop: CGFloat

    var width: CGFloat { digitInkWidth + spacing + boltWidth }

    init(percentage: DuoBatteryPercentage, metrics: DuoGlyphMetrics, displayScale: CGFloat) {
        let density = displayScale.isFinite && displayScale > 0 ? displayScale : 1
        let canvasScale = metrics.overallSize / DuoGlyphMetrics.canvasSize
        let sizeScale = metrics.ringDiameter / DuoGlyphMetrics.standard.ringDiameter * canvasScale
        func snap(_ value: CGFloat) -> CGFloat { (value * density).rounded() / density }
        func ceilPixel(_ value: CGFloat) -> CGFloat { ceil(value * density) / density }
        // The 22-point menu bar cannot accommodate taller ink at 105% without
        // touching the center symbol. Keep that text native-sized, never scaled.
        let nativeSize = snap(11 * sizeScale)
        let menuBarLimit = floor(8.5 * density) / density
        let fontSize = max(1, metrics.overallSize <= 26 ? min(nativeSize, menuBarLimit) : nativeSize)
        let font = NSFont(descriptor: Self.referenceFont.fontDescriptor, size: fontSize) ?? Self.referenceFont
        let key = "\(fontSize):\(percentage.value)" as NSString
        let shaped = Self.shapedDigits.object(forKey: key) ?? ShapedDigits(value: percentage.value, font: font)
        Self.shapedDigits.setObject(shaped, forKey: key)
        let ink = shaped.ink
        let capHeight = ceilPixel(font.capHeight)
        let center = metrics.overallSize / 2
            + (metrics.ringYOffset - metrics.ringDiameter * 0.40 + metrics.contentYOffset) * canvasScale
        // The status item is 22 points high. Keep the ink inside that viewport
        // at normal icon sizes; enlarged previews retain the same proportions.
        let clippingInset = metrics.overallSize <= 26
            ? max(0, (metrics.overallSize - 22) / 2 - DuoGlyphMetrics.menuBarVerticalOffset) : 0

        self.density = density
        self.font = font
        self.capHeight = capHeight
        digitWidth = ceilPixel(shaped.advance)
        digitInkWidth = ink.width
        digitInkLeft = ink.minX
        boltSize = max(1, snap(6 * sizeScale))
        boltWidth = percentage.showsBolt ? ceilPixel(boltSize * 0.8) : 0
        spacing = percentage.showsBolt ? max(1 / density, snap(sizeScale)) : 0
        textHeight = ceilPixel(font.ascender - font.descender + font.leading)
        capTop = max(ceilPixel(clippingInset + 1 / density), snap(center - capHeight / 2))
    }

    func snap(_ value: CGFloat, origin: CGFloat = 0) -> CGFloat {
        ((value + origin) * density).rounded() / density - origin
    }

    func gapDegrees(metrics: DuoGlyphMetrics) -> Double {
        let scale = metrics.overallSize / DuoGlyphMetrics.canvasSize
        let radius = metrics.ringPathDiameter / 2 * scale
        let ringCenterY = metrics.overallSize / 2 + (metrics.ringYOffset + metrics.contentYOffset) * scale
        // Include another half backing pixel for hinted glyph edges.
        let clearance = metrics.arcLineWidth / 2 * scale + 1.5 / density
        // Include the maximum half-pixel shift needed to align the label origin.
        let safeWidth = max(width, digitWidth + spacing + boltWidth) + 1 / density
        let halfWidth = safeWidth / 2 + 0.5 / density + clearance
        let horizontal = 2 * asin(Double(min(1, halfWidth / radius))) * 180 / .pi
        let vertical = 2 * acos(Double(min(1, max(-1,
            (ringCenterY - capTop - capHeight - clearance) / radius)))) * 180 / .pi
        return max(72, min(horizontal, vertical))
    }
}
