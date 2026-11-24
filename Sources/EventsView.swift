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
                // No GlassEffectContainer around the page: neighbouring glass
                // cards inside one container visually merge into each other.
                // Each card carries its own independent .glassEffect instead.
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
        .padding(.bottom, 4)
    }

    private var daysList: some View {
        VStack(spacing: 12) {
            ForEach(week.days, id: \.date) { day in
                dayRow(day)
            }
        }
    }

    private func dayRow(_ day: EventDay) -> some View {
        let isToday = day.date == Day.key(for: Date())
        let expanded = expandedDate == day.date
        let cardGlass: Glass = isToday ? .regular.tint(.blue.opacity(0.25)) : .regular
        let icon = Self.iconName(for: day.title)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                expandedDate = expanded ? nil : day.date
            } label: {
                HStack(spacing: 12) {
                    iconCircle(systemName: icon, color: Self.iconColor(for: icon))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(day.weekday) · \(Self.shortDate(day.date))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(day.title)
                            .font(.headline)
                    }
                    Spacer()
                    if isToday {
                        Text("今天")
                            .font(.caption).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundStyle(Color.white)
                    }
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
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .padding(.leading, 46)
            }
        }
        .padding(16)
        .glassEffect(cardGlass, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }

    private var derbyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                iconCircle(systemName: "trophy.fill", color: .orange)
                Text("德比")
                    .font(.headline)
            }
            Text(week.derby)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private var ongoingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("进行中的长线活动")
                .font(.headline)
            if week.ongoing.isEmpty {
                Text("暂无")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(week.ongoing, id: \.name) { event in
                    HStack(spacing: 10) {
                        let icon = Self.ongoingIconName(for: event.name)
                        iconCircle(systemName: icon,
                                   color: Self.ongoingIconColor(for: icon),
                                   size: 28, iconSize: 13)
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
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Icons

    /// Circular soft-tinted icon badge used by day rows, the derby card and
    /// ongoing-event rows.
    private func iconCircle(systemName: String, color: Color,
                            size: CGFloat = 34, iconSize: CGFloat = 17) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }

    /// Picks an SF Symbol for a day event by keyword in its title, so future
    /// weeks' data (whose titles vary) still get sensible icons.
    /// Order matters: specific matches (小镇, 渔业, 饲料) come before the
    /// generic ones (访客, 加速, 金币) they also contain.
    static func iconName(for title: String) -> String {
        if title.contains("转盘") { return "lifepreserver" }
        if title.contains("小镇") { return "building.2.fill" }
        if title.contains("渔业") || title.contains("鱼") || title.contains("龙虾") { return "fish.fill" }
        if title.contains("饲料") { return "carrot.fill" }
        if title.contains("卡车") { return "truck.box.fill" }
        if title.contains("访客") && title.contains("金币") { return "dollarsign.circle.fill" }
        if title.contains("访客") { return "person.2.wave.2.fill" }
        if title.contains("经验") { return "star.fill" }
        if title.contains("生产") || title.contains("加速") { return "bolt.fill" }
        if title.contains("金币") { return "dollarsign.circle.fill" }
        if title.contains("作物") || title.contains("丰收") { return "leaf.fill" }
        return "calendar"
    }

    static func iconColor(for iconName: String) -> Color {
        switch iconName {
        case "lifepreserver": return .orange
        case "building.2.fill": return .purple
        case "fish.fill": return .blue
        case "carrot.fill": return .orange
        case "truck.box.fill": return .indigo
        case "dollarsign.circle.fill": return .green
        case "person.2.wave.2.fill": return .teal
        case "star.fill": return .yellow
        case "bolt.fill": return .yellow
        case "leaf.fill": return .green
        default: return .red
        }
    }

    /// Icon for an ongoing (long-running) event, matched by keyword in its
    /// name — Chinese names and the original English ones both work.
    static func ongoingIconName(for name: String) -> String {
        if name.contains("船") || name.contains("Sail") { return "sailboat.fill" }
        if name.contains("设计") || name.contains("Design") { return "paintpalette.fill" }
        if name.contains("共育") || name.contains("树") || name.contains("Nurture") { return "tree.fill" }
        return "hourglass"
    }

    static func ongoingIconColor(for iconName: String) -> Color {
        switch iconName {
        case "sailboat.fill": return .blue
        case "paintpalette.fill": return .pink
        case "tree.fill": return .green
        default: return .gray
        }
    }

    /// "2026-11-24" -> "11月24日". Falls back to the raw key if unparsable.
    static func shortDate(_ key: String) -> String {
        guard let date = Day.date(fromKey: key) else { return key }
        let c = Day.calendar.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)月\(c.day ?? 0)日"
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
