import SwiftUI

struct AppNavigationMenu: View {
    @Binding var selection: AppTab

    var body: some View {
        Menu {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    Label(
                        tab.title,
                        systemImage: selection == tab ? "checkmark" : tab.systemImage
                    )
                }
                .accessibilityIdentifier("app-menu-\(tab.title)")
            }
        } label: {
            VerseGlyph(size: 19)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tint(VerseTheme.ink)
        .accessibilityLabel("Open navigation")
        .accessibilityValue(selection.title)
        .accessibilityIdentifier("app-menu")
    }
}

#if DEBUG
#Preview("Navigation menu") {
    AppNavigationMenu(selection: .constant(.articles))
        .padding()
        .background(VerseTheme.paper)
}
#endif
