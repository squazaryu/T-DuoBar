import SwiftUI

struct MenuRowHighlight: ViewModifier {
    var isExpanded = false
    @AppStorage(PreferenceKeys.highlightMenuRows) private var enabled = false
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .background(Color.accentColor.opacity(enabled ? (hovered ? 0.09 : isExpanded ? 0.045 : 0) : 0),
                in: RoundedRectangle(cornerRadius: 7))
            .onHover { hovered = enabled && $0 }
    }
}
