import ActivityKit
import Foundation

struct NextAlarmAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let alarmID: UUID
        let fireDate: Date
        let isTest: Bool
    }
}
