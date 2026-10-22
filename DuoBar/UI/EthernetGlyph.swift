import SwiftUI

/// Monochrome Ethernet status mark matching the reference supplied in issue #4.
/// Drawn as vectors so it remains sharp in the menu bar and the Network row.
struct EthernetGlyph: View {
    static let symbolName = "ethernet.status"
    let width: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.21, y: h * 0.07))
                    path.addLine(to: CGPoint(x: w * 0.04, y: h * 0.5))
                    path.addLine(to: CGPoint(x: w * 0.21, y: h * 0.93))
                    path.move(to: CGPoint(x: w * 0.79, y: h * 0.07))
                    path.addLine(to: CGPoint(x: w * 0.96, y: h * 0.5))
                    path.addLine(to: CGPoint(x: w * 0.79, y: h * 0.93))
                }
                .stroke(style: StrokeStyle(lineWidth: w * 0.078, lineCap: .round, lineJoin: .round))
                ForEach(0..<3) { index in
                    Circle()
                        .frame(width: w * 0.12, height: w * 0.12)
                        .position(x: w * (0.298 + CGFloat(index) * 0.202), y: h * 0.5)
                }
            }
        }
        .frame(width: width, height: width * 0.552)
    }
}
