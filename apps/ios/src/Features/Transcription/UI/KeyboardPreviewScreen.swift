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
                .frame(height: 270)
        }
        .background(Color.white)
    }
}

private struct KeyboardControllerPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> KeyboardViewController {
        let controller = KeyboardViewController()
        controller.isPreview = true
        controller.previewsColdStart = ProcessInfo.processInfo.arguments.contains("--keyboard-cold-ui-testing")
        return controller
    }

    func updateUIViewController(_ controller: KeyboardViewController, context: Context) {}
}
#endif
