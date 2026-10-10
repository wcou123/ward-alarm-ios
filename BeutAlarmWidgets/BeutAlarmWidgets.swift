import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

@main
struct BeutAlarmWidgets: WidgetBundle {
    var body: some Widget { NextAlarmActivity() }
}

struct NextAlarmActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NextAlarmAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "alarm.fill").font(.title2).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.isStale ? "Alarmtijd bereikt" : "Eerstvolgende alarm")
                        .font(.subheadline.weight(.semibold))
                    alarmTime(context.state).font(.title.bold()).monospacedDigit()
                    if context.isStale {
                        Text("Open BeutAlarm voor het actuele overzicht.").font(.caption)
                    } else {
                        Text(context.state.fireDate, format: .dateTime.day().month(.abbreviated))
                            .font(.caption)
                    }
                }
                Spacer(minLength: 0)
                Text("BeutAlarm").font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
            .activitySystemActionForegroundColor(Color.primary)
            .widgetURL(URL(string: "beutalarm://alarms"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("BeutAlarm", systemImage: "alarm.fill").font(.subheadline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    alarmTime(context.state).font(.title2.bold()).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.isStale {
                        Text("Alarmtijd bereikt · Open BeutAlarm").font(.caption)
                    } else {
                        HStack {
                            Text("Eerstvolgende alarm")
                            Spacer()
                            Text(context.state.fireDate, format: .dateTime.day().month(.abbreviated))
                        }.font(.caption)
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
            } compactTrailing: {
                if context.isStale { Image(systemName: "bell.fill") }
                else { alarmTime(context.state).monospacedDigit() }
            } minimal: {
                Image(systemName: context.isStale ? "bell.fill" : "alarm.fill")
            }
            .widgetURL(URL(string: "beutalarm://alarms"))
            .keylineTint(.blue)
        }
    }

    @ViewBuilder
    private func alarmTime(_ state: NextAlarmAttributes.ContentState) -> some View {
        if state.isTest {
            Text(state.fireDate, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits).locale(Locale(identifier: "nl_BE")))
        } else {
            Text(state.fireDate, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "nl_BE")))
        }
    }
}
