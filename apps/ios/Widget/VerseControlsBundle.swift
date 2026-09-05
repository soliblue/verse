import SwiftUI
import WidgetKit

@main
struct VerseControlsBundle: WidgetBundle {
    var body: some Widget {
        DictationLiveActivity()
        if #available(iOS 18.0, *) {
            DictationControl()
        }
    }
}
