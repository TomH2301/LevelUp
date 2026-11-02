import Foundation
import UserNotifications

enum NotificationManager {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func schedule(for task: TaskItem) {
        cancel(for: task)
        guard !task.isDone else { return }

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.sound = .default

        let center = UNUserNotificationCenter.current()

        if task.repeatWeekdays.isEmpty {
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: task.dueDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: task.notificationID, content: content, trigger: trigger)
            center.add(request)
        } else {
            let timeComps = Calendar.current.dateComponents([.hour, .minute], from: task.dueDate)
            for weekday in task.repeatWeekdays {
                var comps = DateComponents()
                comps.weekday = weekday
                comps.hour = timeComps.hour
                comps.minute = timeComps.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let request = UNNotificationRequest(identifier: identifier(for: task, weekday: weekday), content: content, trigger: trigger)
                center.add(request)
            }
        }
    }

    static func cancel(for task: TaskItem) {
        let center = UNUserNotificationCenter.current()
        if task.repeatWeekdays.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: [task.notificationID])
        } else {
            let ids = task.repeatWeekdays.map { identifier(for: task, weekday: $0) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private static func identifier(for task: TaskItem, weekday: Int) -> String {
        "\(task.notificationID)-\(weekday)"
    }
}
