import SwiftUI
import SwiftData
import Charts

struct BodyMetricsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMetricEntry.date) private var entries: [BodyMetricEntry]
    @State private var isAddingEntry = false

    var body: some View {
        NavigationStack {
            List {
                if !entries.isEmpty {
                    Section("Verlauf") {
                        chart
                            .frame(height: 220)
                            .padding(.vertical, 8)
                    }
                }

                Section("Einträge") {
                    ForEach(entries) { entry in
                        EntryRow(entry: entry)
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
            .navigationTitle("Körper")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingEntry) {
                AddBodyMetricView()
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Einträge",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Tippe auf + um Gewicht oder Körperfettanteil einzutragen.")
                    )
                }
            }
        }
    }

    private var chart: some View {
        Chart(entries) { entry in
            LineMark(
                x: .value("Datum", entry.date),
                y: .value("Gewicht", entry.weightKg)
            )
            .foregroundStyle(.blue)

            PointMark(
                x: .value("Datum", entry.date),
                y: .value("Gewicht", entry.weightKg)
            )
            .foregroundStyle(.blue)
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

private struct EntryRow: View {
    let entry: BodyMetricEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                if let kfa = entry.bodyFatPercentage {
                    Text("KFA: \(kfa.formatted(.number.precision(.fractionLength(1)))) %")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(entry.weightKg.formatted(.number.precision(.fractionLength(1)))) kg")
                .font(.body.monospacedDigit())
        }
    }
}

#Preview {
    BodyMetricsView()
        .modelContainer(for: BodyMetricEntry.self, inMemory: true)
}
