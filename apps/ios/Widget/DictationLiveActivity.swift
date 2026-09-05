import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct DictationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictationActivityAttributes.self) { context in
            HStack(spacing: 16) {
                Image(systemName: context.state.phase == "recording" ? "waveform" : "mic.fill")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verse").font(.headline)
                    Text(label(context.state.phase)).font(.caption)
                }
                Spacer()
                controls(context.state.phase)
            }
            .padding(20)
            .activityBackgroundTint(Color(red: 1, green: 0.96, blue: 0.72))
            .activitySystemActionForegroundColor(.black)
            .foregroundStyle(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Verse", systemImage: "waveform")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(label(context.state.phase)).font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    controls(context.state.phase)
                }
            } compactLeading: {
                Image(systemName: "waveform")
            } compactTrailing: {
                Image(systemName: context.state.phase == "recording" ? "record.circle" : "mic.fill")
            } minimal: {
                Image(systemName: "waveform")
            }
            .keylineTint(.orange)
        }
    }

    private func label(_ phase: String) -> String {
        switch phase {
        case "recording": "Recording"
        case "transcribing": "Transcribing"
        default: "Microphone ready"
        }
    }

    @ViewBuilder
    private func controls(_ phase: String) -> some View {
        HStack(spacing: 12) {
            if #available(iOS 18.0, *), phase != "transcribing" {
                Button(intent: ToggleDictationIntent()) {
                    Label(phase == "recording" ? "Transcribe" : "Speak", systemImage: phase == "recording" ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            Button(intent: EndDictationSessionIntent()) {
                Image(systemName: "xmark")
                    .frame(minWidth: 32, minHeight: 32)
            }
            .accessibilityLabel("End session")
            .buttonStyle(.bordered)
        }
    }
}
