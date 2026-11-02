import SwiftUI
import UserNotifications

struct RestTimerBar: View {
    @State private var endDate: Date?

    var body: some View {
        HStack(spacing: 12) {
            ForEach([2, 3, 4], id: \.self) { minutes in
                Button("\(minutes) min") {
                    start(minutes: minutes)
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if let endDate {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(endDate.timeIntervalSince(context.date)))
                    Text(timeString(remaining))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(remaining == 0 ? .secondary : .blue)
                }
            }
        }
    }

    private func start(minutes: Int) {
        endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        scheduleNotification(seconds: minutes * 60)
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func scheduleNotification(seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Pause vorbei"
        content.body = "Weiter geht's!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "rest-timer-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
