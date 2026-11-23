import CoreGraphics

enum DesktopIndicatorSize: String, CaseIterable, Identifiable {
    case small, medium, large

    static let defaultSize: Self = .medium

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var edge: CGFloat {
        switch self {
        case .small: 64
        case .medium: 84
        case .large: 108
        }
    }

    static func resolve(_ rawValue: String?) -> Self {
        rawValue.flatMap(Self.init(rawValue:)) ?? defaultSize
    }
}

struct DesktopIndicatorScreen {
    let id: String
    let visibleFrame: CGRect
}

struct DesktopIndicatorPlacement: Codable, Equatable {
    let screenID: String
    let x: Double
    let y: Double

    static func frame(
        size: DesktopIndicatorSize,
        placement: Self?,
        screens: [DesktopIndicatorScreen]
    ) -> CGRect? {
        // AppKit lists the primary display first. A disconnected display's
        // saved position survives a temporary fallback to the primary display.
        guard let screen = screens.first(where: { $0.id == placement?.screenID }) ?? screens.first else {
            return nil
        }
        let visible = screen.visibleFrame
        let edge = min(size.edge, visible.width, visible.height)
        let horizontalSpace = visible.width - edge
        let verticalSpace = visible.height - edge
        let xOffset = placement.map { horizontalSpace * unitFraction($0.x) } ?? max(0, horizontalSpace - 18)
        let yOffset = placement.map { verticalSpace * unitFraction($0.y) } ?? max(0, verticalSpace - 18)
        return CGRect(x: visible.minX + xOffset, y: visible.minY + yOffset, width: edge, height: edge)
    }

    static func capture(frame: CGRect, screens: [DesktopIndicatorScreen]) -> Self? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let screen = screens.max {
            let left = frame.intersection($0.visibleFrame)
            let right = frame.intersection($1.visibleFrame)
            let leftArea = left.isNull ? 0 : left.width * left.height
            let rightArea = right.isNull ? 0 : right.width * right.height
            if leftArea != rightArea { return leftArea < rightArea }
            return distanceSquared(from: center, to: $0.visibleFrame) > distanceSquared(from: center, to: $1.visibleFrame)
        }
        guard let screen else { return nil }

        let visible = screen.visibleFrame
        let horizontalSpace = max(1, visible.width - frame.width)
        let verticalSpace = max(1, visible.height - frame.height)
        return Self(
            screenID: screen.id,
            x: unitFraction((frame.minX - visible.minX) / horizontalSpace),
            y: unitFraction((frame.minY - visible.minY) / verticalSpace)
        )
    }

    private static func distanceSquared(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = point.x - min(max(point.x, rect.minX), rect.maxX)
        let dy = point.y - min(max(point.y, rect.minY), rect.maxY)
        return dx * dx + dy * dy
    }

    private static func unitFraction(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 1
    }
}
