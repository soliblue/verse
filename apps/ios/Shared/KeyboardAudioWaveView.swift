#if !VERSE_WIDGET
import UIKit

final class KeyboardAudioWaveView: UIView {
    private var levels = Array(repeating: 0.0, count: 11)
    private let bars = (0..<11).map { _ in CALayer() }
    private var lastBounds = CGRect.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        for bar in bars {
            bar.backgroundColor = UIColor(red: 0.89, green: 0.29, blue: 0.04, alpha: 1).cgColor
            bar.cornerRadius = 1.5
            layer.addSublayer(bar)
        }
    }

    required init?(coder: NSCoder) { nil }

    func update(level: Double, recording: Bool) {
        levels = recording ? Array(levels.dropFirst()) + [min(1, max(0, level))] : Array(repeating: 0, count: 11)
        isHidden = !recording
        layoutBars(animated: recording && window != nil)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard lastBounds != bounds else { return }
        lastBounds = bounds
        layoutBars(animated: false)
    }

    private func layoutBars(animated: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            let height = max(3, CGFloat(levels[index].squareRoot()) * min(28, max(3, bounds.height - 6)))
            let previous = bar.presentation()?.bounds.size.height ?? bar.bounds.height
            bar.bounds = CGRect(x: 0, y: 0, width: 3, height: height)
            bar.position = CGPoint(x: bounds.midX + CGFloat(index - 5) * 6, y: bounds.midY)
            if animated && !UIAccessibility.isReduceMotionEnabled {
                let animation = CABasicAnimation(keyPath: "bounds.size.height")
                animation.fromValue = previous
                animation.toValue = height
                animation.duration = 0.1
                animation.timingFunction = CAMediaTimingFunction(name: .linear)
                let maximum = Float(window?.windowScene?.screen.maximumFramesPerSecond ?? 60)
                animation.preferredFrameRateRange = CAFrameRateRange(minimum: min(60, maximum), maximum: maximum, preferred: maximum)
                bar.add(animation, forKey: "level")
            } else {
                bar.removeAllAnimations()
            }
        }
        CATransaction.commit()
    }
}
#endif
