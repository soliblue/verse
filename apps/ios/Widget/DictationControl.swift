import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct DictationControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "soli.verse.dictation") {
            ControlWidgetButton(action: ToggleDictationIntent()) {
                Label("Dictate", systemImage: "mic.fill")
            }
        }
        .displayName("Verse dictation")
        .description("Start speaking. Tap again to transcribe.")
    }
}
