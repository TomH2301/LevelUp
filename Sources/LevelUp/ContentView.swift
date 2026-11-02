import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TaskListView()
                .tabItem {
                    Label("Aufgaben", systemImage: "checklist")
                }

            BodyMetricsView()
                .tabItem {
                    Label("Körper", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
    }
}

#Preview {
    ContentView()
}
