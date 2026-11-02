import SwiftUI
import UserNotifications
import Combine

struct RestTimerBar: View {
    @State private var remainingSeconds: Int = 0
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        HStack(spacing: 12) {
            ForEach([2, 3, 4], id: \.self) { minutes in
                Button("\(minutes) min") {
                    start(minutes: minutes)
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if remainingSeconds > 0 {
                Text(timeString(remainingSeconds))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.blue)
            }
        }
    }

    private func start(minutes: Int) {
        remainingSeconds = minutes * 60
        scheduleNotification(seconds: minutes * 60)

        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if remainingSeconds > 0 {
                    remainingSeconds -= 1
                }
            }
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
