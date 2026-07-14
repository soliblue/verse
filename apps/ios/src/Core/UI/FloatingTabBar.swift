import SwiftUI

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .foregroundStyle(selection == tab ? VerseTheme.paper : VerseTheme.ink)
                        .background(selection == tab ? VerseTheme.ink : .clear, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityValue(selection == tab ? "Selected" : "")
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(VerseTheme.border, lineWidth: 1)
        }
        .shadow(color: VerseTheme.ink.opacity(0.12), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("verse-floating-tabs")
    }
}

#if DEBUG
#Preview("Floating tabs") {
    FloatingTabBar(selection: .constant(.today))
        .padding()
        .background(VerseTheme.paper)
}
#endif
