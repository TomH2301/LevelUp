import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TaskListView()
                .tabItem {
                    Label("Aufgaben", systemImage: "checklist")
                }
        }
    }
}

#Preview {
    ContentView()
}
