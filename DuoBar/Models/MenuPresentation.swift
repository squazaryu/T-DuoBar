import SwiftUI

struct MenuTypography: Equatable {
    var readable = false
    var scale: CGFloat { readable ? 1.14 : 1 }
    var secondary: AnyShapeStyle {
        readable ? AnyShapeStyle(Color.primary.opacity(0.78)) : AnyShapeStyle(HierarchicalShapeStyle.secondary)
    }
    var compactHeight: CGFloat { readable ? 40 : 34 }
    func size(_ points: CGFloat) -> CGFloat { points * scale }
}

enum MenuPresentation {
    static func width(wide: Bool) -> CGFloat { wide ? 360 : 304 }
    static func width(defaults: UserDefaults) -> CGFloat { width(wide: defaults.bool(forKey: PreferenceKeys.widePopover)) }
}

private struct MenuTypographyKey: EnvironmentKey { static let defaultValue = MenuTypography() }
private struct ExpandedMenuSectionKey: EnvironmentKey { static let defaultValue: Binding<UUID?> = .constant(nil) }
extension EnvironmentValues {
    var menuTypography: MenuTypography {
        get { self[MenuTypographyKey.self] }
        set { self[MenuTypographyKey.self] = newValue }
    }
    var expandedMenuSection: Binding<UUID?> {
        get { self[ExpandedMenuSectionKey.self] }
        set { self[ExpandedMenuSectionKey.self] = newValue }
    }
}

/// Own expansion state inside an installed view, including standalone renders.
struct MenuSectionExpansionScope: ViewModifier {
    @State private var active: UUID?
    func body(content: Content) -> some View {
        content.environment(\.expandedMenuSection, $active)
    }
}
