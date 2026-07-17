import SwiftUI
import UIKit

struct KeyboardDismissalHost: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WindowObserverView {
        let view = WindowObserverView()
        let coordinator = context.coordinator
        view.isUserInteractionEnabled = false
        view.onWindowChange = { [weak coordinator] window in
            coordinator?.install(in: window)
        }
        return view
    }

    func updateUIView(_ uiView: WindowObserverView, context: Context) {
        context.coordinator.install(in: uiView.window)
    }

    static func dismantleUIView(_ uiView: WindowObserverView, coordinator: Coordinator) {
        uiView.onWindowChange = nil
        coordinator.uninstall()
    }

    final class WindowObserverView: UIView {
        var onWindowChange: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChange?(window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private var tapRecognizer: UITapGestureRecognizer?

        func install(in nextWindow: UIWindow?) {
            guard window !== nextWindow else { return }
            uninstall()
            guard let nextWindow else { return }

            let tapRecognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(dismissKeyboard)
            )
            tapRecognizer.cancelsTouchesInView = false
            tapRecognizer.delegate = self
            nextWindow.addGestureRecognizer(tapRecognizer)
            window = nextWindow
            self.tapRecognizer = tapRecognizer
        }

        func uninstall() {
            if let tapRecognizer {
                window?.removeGestureRecognizer(tapRecognizer)
            }
            tapRecognizer = nil
            window = nil
        }

        @objc private func dismissKeyboard() {
            window?.endEditing(true)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var touchedView = touch.view
            while let view = touchedView {
                if view is UITextField || view is UITextView {
                    return false
                }
                touchedView = view.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
