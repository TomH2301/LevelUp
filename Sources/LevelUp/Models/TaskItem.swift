import Foundation
import SwiftData

@Model
final class TaskItem {
    var title: String
    var dueDate: Date
    var isDone: Bool
    /// 1 = Sonntag ... 7 = Samstag (Calendar.Component.weekday). Leer = einmalige Aufgabe.
    var repeatWeekdays: [Int]
    var notificationID: String

    init(title: String, dueDate: Date, isDone: Bool = false, repeatWeekdays: [Int] = []) {
        self.title = title
        self.dueDate = dueDate
        self.isDone = isDone
        self.repeatWeekdays = repeatWeekdays
        self.notificationID = UUID().uuidString
    }
}
