#if DEBUG
import SwiftUI

struct KeyboardPreviewScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Keyboard layout preview")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
            Spacer()
            KeyboardControllerPreview()
                .frame(height: 260)
        }
        .background(Color.white)
    }
}

private struct KeyboardControllerPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> KeyboardViewController {
        let controller = KeyboardViewController()
        controller.isPreview = true
        return controller
    }

    func updateUIViewController(_ controller: KeyboardViewController, context: Context) {}
}
#endif
