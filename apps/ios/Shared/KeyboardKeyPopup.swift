#if !VERSE_WIDGET
import UIKit

final class KeyboardKeyPopup: UIView {
    private let shape = CAShapeLayer()
    private let character = UILabel()
    private var sourceFrame = CGRect.null
    private var sourceWidth: CGFloat = 0
    private var darkAppearance = false

    var text: String { character.text ?? "" }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityIdentifier = "keyboard-key-preview"
        layer.addSublayer(shape)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        character.font = .systemFont(ofSize: 32)
        character.textAlignment = .center
        addSubview(character)
    }

    required init?(coder: NSCoder) { return nil }

    func update(text: String, keyFrame: CGRect, keyboardWidth: CGFloat, dark: Bool) {
        guard self.text != text || sourceFrame != keyFrame || sourceWidth != keyboardWidth || darkAppearance != dark else { return }
        sourceFrame = keyFrame
        sourceWidth = keyboardWidth
        darkAppearance = dark
        let rise: CGFloat = 44
        let width = keyFrame.width + 28
        let x = min(max(0, keyFrame.midX - width / 2), keyboardWidth - width)
        frame = CGRect(x: x, y: keyFrame.minY - rise, width: width, height: keyFrame.height + rise)
        let left = keyFrame.minX - x
        let right = left + keyFrame.width
        let bottom = bounds.height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 11, y: 0))
        path.addLine(to: CGPoint(x: width - 11, y: 0))
        path.addQuadCurve(to: CGPoint(x: width, y: 11), controlPoint: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: 35))
        path.addQuadCurve(to: CGPoint(x: width - 9, y: 44), controlPoint: CGPoint(x: width, y: 44))
        path.addQuadCurve(to: CGPoint(x: right, y: 53), controlPoint: CGPoint(x: right, y: 44))
        path.addLine(to: CGPoint(x: right, y: bottom - 5))
        path.addQuadCurve(to: CGPoint(x: right - 5, y: bottom), controlPoint: CGPoint(x: right, y: bottom))
        path.addLine(to: CGPoint(x: left + 5, y: bottom))
        path.addQuadCurve(to: CGPoint(x: left, y: bottom - 5), controlPoint: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: left, y: 53))
        path.addQuadCurve(to: CGPoint(x: 9, y: 44), controlPoint: CGPoint(x: left, y: 44))
        path.addQuadCurve(to: CGPoint(x: 0, y: 35), controlPoint: CGPoint(x: 0, y: 44))
        path.addLine(to: CGPoint(x: 0, y: 11))
        path.addQuadCurve(to: CGPoint(x: 11, y: 0), controlPoint: .zero)
        path.close()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.path = path.cgPath
        shape.fillColor = (dark ? UIColor(white: 0.39, alpha: 1) : .white).cgColor
        layer.shadowPath = path.cgPath
        layer.shadowOpacity = dark ? 0.28 : 0.2
        CATransaction.commit()
        character.text = text
        character.textColor = dark ? .white : .black
        character.frame = CGRect(x: 0, y: 1, width: width, height: rise)
        accessibilityLabel = text
    }
}
#endif
