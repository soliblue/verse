#if !VERSE_WIDGET
import UIKit

final class KeyboardAudioWaveView: UIView {
    private var levels = Array(repeating: 0.0, count: 11)

    func update(level: Double, recording: Bool) {
        levels = recording ? Array(levels.dropFirst()) + [min(1, max(0, level))] : Array(repeating: 0, count: 11)
        isHidden = !recording
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        UIColor(red: 0.89, green: 0.29, blue: 0.04, alpha: 1).setStroke()
        let path = UIBezierPath()
        path.lineWidth = 3
        path.lineCapStyle = .round
        for (index, level) in levels.enumerated() {
            let height = max(2, CGFloat(level.squareRoot()) * min(28, rect.height - 6))
            let x = rect.midX + CGFloat(index - 5) * 6
            path.move(to: CGPoint(x: x, y: rect.midY - height / 2))
            path.addLine(to: CGPoint(x: x, y: rect.midY + height / 2))
        }
        path.stroke()
    }
}
#endif
