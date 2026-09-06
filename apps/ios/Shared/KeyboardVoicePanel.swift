#if !VERSE_WIDGET
import UIKit

final class KeyboardVoicePanel: UIView {
    let waveform = KeyboardAudioWaveView(barCount: 49, maximumHeight: 80)
    let globe = UIButton(type: .system)
    private let elapsed = UILabel()

    var actionFrame: CGRect {
        let side = max(0, min(176, min(bounds.width - 64, bounds.height - 24)))
        return CGRect(x: bounds.midX - side / 2, y: (bounds.height - side) / 2 - 4, width: side, height: side)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "keyboard-voice-panel"
        backgroundColor = .clear
        waveform.isHidden = true
        waveform.accessibilityIdentifier = "keyboard-voice-waveform"
        addSubview(waveform)
        elapsed.font = .monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        elapsed.textAlignment = .center
        elapsed.textColor = .label
        elapsed.accessibilityIdentifier = "keyboard-recording-duration"
        elapsed.isHidden = true
        addSubview(elapsed)
        globe.setImage(UIImage(systemName: "globe"), for: .normal)
        globe.setPreferredSymbolConfiguration(.init(pointSize: 22), forImageIn: .normal)
        globe.accessibilityLabel = "Next keyboard"
        globe.accessibilityIdentifier = "keyboard-voice-next-keyboard"
        addSubview(globe)
    }

    required init?(coder: NSCoder) { nil }

    func update(level: Double, recording: Bool, startedAt: Double) {
        waveform.update(level: level, recording: recording)
        elapsed.isHidden = !recording
        guard recording else { return }
        let duration = Date().timeIntervalSince1970 - startedAt
        let seconds = startedAt > 0 && duration.isFinite ? Int(min(3600, max(0, duration))) : 0
        let text = String(format: "%d:%02d", seconds / 60, seconds % 60)
        if elapsed.text != text { elapsed.text = text }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        waveform.frame = CGRect(x: 20, y: 34, width: max(0, bounds.width - 40), height: 96)
        elapsed.frame = CGRect(x: 0, y: 145, width: bounds.width, height: 24)
        globe.frame = CGRect(x: 12, y: bounds.height - 46, width: 44, height: 44)
    }
}
#endif
