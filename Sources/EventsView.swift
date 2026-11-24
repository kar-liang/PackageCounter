import Foundation
import SwiftUI

/// Remote source for the weekly Hay Day events. The app fetches this JSON on
/// launch; when the fetch fails it falls back to the cached copy, and finally
/// to the bundled snapshot in EventsData.
let EVENTS_JSON_URL = "https://raw.githubusercontent.com/kar-liang/iconpack/master/data/hayday-events.json"

struct EventDay: Codable, Equatable {
    /// "yyyy-MM-dd" in the local calendar.
    var date: String
    var weekday: String
    var title: String
    var detail: String
}

struct OngoingEvent: Codable, Equatable {
    var name: String
    var dates: String
}

struct EventsWeek: Codable, Equatable {
    var weekLabel: String
    var rangeLabel: String
    var days: [EventDay]
    var derby: String
    var ongoing: [OngoingEvent]
    var updatedAt: String
}

struct EventsView: View {
    @State private var week: EventsWeek
    @State private var expandedDate: String?

    private let cacheKey = "packageCounter.eventsWeek.v1"

    init() {
        // Render immediately: cached remote copy if we have one, otherwise
        // the bundled snapshot. The remote refresh happens in .task below.
        if let data = UserDefaults.standard.data(forKey: "packageCounter.eventsWeek.v1"),
           let cached = try? JSONDecoder().decode(EventsWeek.self, from: data) {
            _week = State(initialValue: cached)
        } else {
            _week = State(initialValue: EventsData.fallbackWeek)
        }
        let todayKey = Day.key(for: Date())
        _expandedDate = State(initialValue: todayKey)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    daysList
                    derbyCard
                    ongoingCard
                    Text("数据更新于 \(week.updatedAt)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("活动日历")
            .task {
                await refreshFromRemote()
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(week.weekLabel)
                .font(.title2).bold()
            Text(week.rangeLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var daysList: some View {
        VStack(spacing: 8) {
            ForEach(week.days, id: \.date) { day in
                dayRow(day)
            }
        }
    }

    private func dayRow(_ day: EventDay) -> some View {
        let isToday = day.date == Day.key(for: Date())
        let expanded = expandedDate == day.date
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                expandedDate = expanded ? nil : day.date
            } label: {
                HStack(spacing: 10) {
                    Text(day.weekday)
                        .font(.subheadline).bold()
                        .frame(width: 36, alignment: .leading)
                    Text(day.date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(day.title)
                        .font(.subheadline).bold()
                    if isToday {
                        Text("今天")
                            .font(.caption).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundStyle(Color.white)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Text(day.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isToday ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }

    private var derbyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("德比")
                .font(.headline)
            Text(week.derby)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
    }

    private var ongoingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("进行中的长线活动")
                .font(.headline)
            if week.ongoing.isEmpty {
                Text("暂无")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(week.ongoing, id: \.name) { event in
                    HStack {
                        Text(event.name)
                            .font(.subheadline)
                        Spacer()
                        Text(event.dates)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
    }

    // MARK: - Remote refresh

    private func refreshFromRemote() async {
        guard let url = URL(string: EVENTS_JSON_URL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let remote = try JSONDecoder().decode(EventsWeek.self, from: data)
            week = remote
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            // Offline or bad payload: keep showing the bundled/cached data.
        }
    }
}
