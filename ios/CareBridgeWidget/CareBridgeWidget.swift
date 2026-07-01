import WidgetKit
import SwiftUI

// MARK: - Data model

struct WellnessEntry: TimelineEntry {
    let date: Date
    let patientName: String
    let wellnessScore: Int
    let energy: Int
    let mood: Int
    let lastCheckin: String
    let hasData: Bool
}

// MARK: - Provider

struct WellnessProvider: TimelineProvider {
    private let suiteName = "group.com.carebridge.app"

    func placeholder(in context: Context) -> WellnessEntry {
        WellnessEntry(date: Date(), patientName: "Alice Johnson", wellnessScore: 72,
                      energy: 7, mood: 6, lastCheckin: "Today", hasData: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (WellnessEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WellnessEntry>) -> Void) {
        let entry = readEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func readEntry() -> WellnessEntry {
        let d = UserDefaults(suiteName: suiteName)
        let name = d?.string(forKey: "widget_patient_name") ?? ""
        let score = d?.integer(forKey: "widget_wellness_score") ?? 0
        let energy = d?.integer(forKey: "widget_energy") ?? 0
        let mood = d?.integer(forKey: "widget_mood") ?? 0
        let checkin = d?.string(forKey: "widget_last_checkin") ?? "—"
        return WellnessEntry(date: Date(), patientName: name, wellnessScore: score,
                             energy: energy, mood: mood, lastCheckin: checkin,
                             hasData: !name.isEmpty && score > 0)
    }
}

// MARK: - Helpers

private func scoreColor(_ score: Int) -> Color {
    if score >= 80 { return Color(red: 16/255, green: 185/255, blue: 129/255) }
    if score >= 60 { return Color(red: 245/255, green: 158/255, blue: 11/255) }
    return Color(red: 239/255, green: 68/255, blue: 68/255)
}

private func scoreLabel(_ score: Int) -> String {
    if score >= 80 { return "Excellent" }
    if score >= 60 { return "Moderate" }
    return "Needs Attention"
}

private let cbPrimary = Color(red: 59/255, green: 130/255, blue: 246/255)

// MARK: - Small widget

struct SmallWellnessView: View {
    let entry: WellnessEntry

    var body: some View {
        if entry.hasData {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(cbPrimary)
                        .frame(width: 8, height: 8)
                    Text("CareBridge")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(cbPrimary)
                }

                Spacer()

                Text("\(entry.wellnessScore)")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(scoreColor(entry.wellnessScore))
                    .minimumScaleFactor(0.7)

                Text(scoreLabel(entry.wellnessScore))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(scoreColor(entry.wellnessScore))

                Text(entry.patientName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .drawingGroup()
                Text("Open CareBridge\nto sync data")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}

// MARK: - Medium widget

struct MediumWellnessView: View {
    let entry: WellnessEntry

    var body: some View {
        if entry.hasData {
            HStack(spacing: 0) {
                // Left column — score
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Circle().fill(cbPrimary).frame(width: 7, height: 7)
                        Text("CareBridge")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(cbPrimary)
                    }

                    Spacer()

                    Text("\(entry.wellnessScore)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor(entry.wellnessScore))
                        .minimumScaleFactor(0.6)

                    Text("Wellness")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(scoreColor(entry.wellnessScore))

                    Text(entry.patientName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 0.5)
                    .padding(.vertical, 14)

                // Right column — metrics
                VStack(alignment: .leading, spacing: 10) {
                    metricRow(label: "Energy", value: entry.energy,
                              icon: "bolt.fill", color: .orange)
                    metricRow(label: "Mood", value: entry.mood,
                              icon: "face.smiling", color: Color(red: 0.4, green: 0.7, blue: 0.4))

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.black.opacity(0.45))
                        Text(entry.lastCheckin)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.black.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        } else {
            HStack(spacing: 14) {
                Image("Logo")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                Text("Open CareBridge to sync your wellness data")
                    .font(.callout)
                    .foregroundStyle(Color.black.opacity(0.5))
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func metricRow(label: String, value: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)
            Spacer()
            Text("\(value)/10")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.5))
        }
    }
}

// MARK: - Large widget

struct LargeWellnessView: View {
    let entry: WellnessEntry

    var body: some View {
        if entry.hasData {
            VStack(spacing: 0) {
                // Top half — score
                VStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 4) {
                        Circle().fill(cbPrimary).frame(width: 8, height: 8)
                        Text("CareBridge Wellness")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(cbPrimary)
                    }

                    Text("\(entry.wellnessScore)")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor(entry.wellnessScore))
                        .minimumScaleFactor(0.6)

                    Text(entry.patientName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Bottom half — metrics
                VStack(alignment: .leading, spacing: 14) {
                    metricRow(label: "Energy", value: entry.energy, icon: "bolt.fill", color: .orange)
                    metricRow(label: "Mood", value: entry.mood, icon: "face.smiling", color: Color(red: 0.4, green: 0.7, blue: 0.4))
                    
                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.black.opacity(0.45))
                        Text("Last sync: \(entry.lastCheckin)")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.black.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            VStack(spacing: 16) {
                Image("Logo")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)
                    .drawingGroup()
                Text("Open CareBridge to sync\nyour wellness data")
                    .font(.headline)
                    .foregroundStyle(Color.black.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func metricRow(label: String, value: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black)
            Spacer()
            Text("\(value)/10")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.5))
        }
    }
}

// MARK: - Entry view

struct CareBridgeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: WellnessProvider.Entry

    var body: some View {
        switch family {
        case .systemLarge:
            LargeWellnessView(entry: entry)
                .containerBackground(.white, for: .widget)
        case .systemMedium:
            MediumWellnessView(entry: entry)
                .containerBackground(.white, for: .widget)
        default:
            SmallWellnessView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
    }
}

// MARK: - Widget

struct CareBridgeWidget: Widget {
    let kind: String = "CareBridgeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WellnessProvider()) { entry in
            CareBridgeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Wellness Score")
        .description("Your daily wellness score at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    CareBridgeWidget()
} timeline: {
    WellnessEntry(date: .now, patientName: "Alice Johnson", wellnessScore: 72,
                  energy: 7, mood: 6, lastCheckin: "Today, 2:30 PM", hasData: true)
    WellnessEntry(date: .now, patientName: "Alice Johnson", wellnessScore: 45,
                  energy: 3, mood: 4, lastCheckin: "Yesterday", hasData: true)
}

#Preview(as: .systemMedium) {
    CareBridgeWidget()
} timeline: {
    WellnessEntry(date: .now, patientName: "Alice Johnson", wellnessScore: 72,
                  energy: 7, mood: 6, lastCheckin: "Today, 2:30 PM", hasData: true)
}
