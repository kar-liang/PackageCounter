import SwiftUI

struct CounterView: View {
    @EnvironmentObject private var store: Store
    @State private var showingSettings = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    accountSwitcher
                    if let account = store.selectedAccount {
                        progressCard(account)
                        actionButtons(account)
                        gridCard(account)
                    } else {
                        Text("还没有账号，点右上角 + 新建一个。")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("HayDay 助手")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("套餐设置", systemImage: "gearshape")
                    }
                    .disabled(store.selectedAccount == nil)
                }
            }
            .sheet(isPresented: $showingSettings) {
                if let account = store.selectedAccount {
                    SettingsView(account: account)
                        .environmentObject(store)
                }
            }
        }
    }

    // MARK: - Account switcher

    private var accountSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.accounts) { account in
                    Button {
                        store.select(account)
                    } label: {
                        Text(account.name)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(
                                    store.selectedAccount?.id == account.id
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.15)
                                )
                            )
                            .foregroundStyle(
                                store.selectedAccount?.id == account.id ? Color.white : Color.primary
                            )
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    store.addAccount()
                } label: {
                    Label("添加账号", systemImage: "plus")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().stroke(Color.accentColor))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Progress

    private func progressCard(_ account: PackageAccount) -> some View {
        VStack(spacing: 6) {
            Text("已发 \(account.shippedCount) / \(account.totalDays)")
                .font(.title2).bold()
            Text("还剩 \(account.remainingCount) 次")
                .foregroundStyle(.secondary)
            if let last = account.lastDate {
                Text("预计最后一次：\(last, format: Self.dateFormat)")
                    .foregroundStyle(.secondary)
            } else {
                Text("尚未开始")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
    }

    // MARK: - Actions

    private func todayButtonState(_ account: PackageAccount) -> (enabled: Bool, hint: String) {
        guard account.startDate != nil else { return (false, "尚未开始，先在设置里选开始日期") }
        let today = Date()
        guard account.contains(today) else {
            if let start = account.startDate, Day.startOfDay(today) < Day.startOfDay(start) {
                return (false, "套餐还没开始")
            }
            return (false, "套餐已结束")
        }
        if account.isShipped(today) { return (false, "今天已经发过货了") }
        return (true, "")
    }

    private func actionButtons(_ account: PackageAccount) -> some View {
        let state = todayButtonState(account)
        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    store.markTodayShipped(accountID: account.id)
                } label: {
                    Text("今日已发货")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!state.enabled)

                Button {
                    store.undoLastShipment(accountID: account.id)
                } label: {
                    Text("撤销上一次")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(account.shippedCount == 0)
            }
            if !state.hint.isEmpty {
                Text(state.hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 30-day grid

    private func gridCard(_ account: PackageAccount) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if account.startDate == nil {
                Text("未开始：在「套餐设置」里填开始日期后，这里会生成 \(account.totalDays) 天的格子。")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(0..<account.totalDays, id: \.self) { index in
                        if let date = account.date(forCell: index) {
                            let shipped = account.isShipped(date)
                            let isToday = Day.key(for: date) == Day.key(for: Date())
                            Button {
                                store.toggleShipped(accountID: account.id, date: date)
                            } label: {
                                VStack(spacing: 1) {
                                    Text("\(Day.calendar.component(.day, from: date))")
                                        .font(.subheadline).bold()
                                    Text(date, format: Self.monthFormat)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(shipped ? Color.green.opacity(0.75) : Color.secondary.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                                .foregroundStyle(shipped ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Text("点格子可以补记 / 取消某一天的发货。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
    }

    static let dateFormat = Date.FormatStyle(date: .long, time: .omitted)
    static let monthFormat = Date.FormatStyle().month(.abbreviated)
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let account: PackageAccount

    @State private var name: String
    @State private var hasStarted: Bool
    @State private var startDate: Date
    @State private var totalDays: Int

    init(account: PackageAccount) {
        self.account = account
        _name = State(initialValue: account.name)
        _hasStarted = State(initialValue: account.startDate != nil)
        _startDate = State(initialValue: account.startDate ?? Date())
        _totalDays = State(initialValue: account.totalDays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("账号") {
                    TextField("名称", text: $name)
                }
                Section("套餐") {
                    Toggle("已开始", isOn: $hasStarted)
                    if hasStarted {
                        DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    } else {
                        Text("未开始：暂无开始日期")
                            .foregroundStyle(.secondary)
                    }
                    Stepper("总天数：\(totalDays) 天", value: $totalDays, in: 1...120)
                }
            }
            .navigationTitle("套餐设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.updateSettings(
                            accountID: account.id,
                            name: name.isEmpty ? account.name : name,
                            startDate: hasStarted ? startDate : nil,
                            totalDays: totalDays
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Root (tabs)

struct ContentView: View {
    var body: some View {
        TabView {
            CounterView()
                .tabItem {
                    Label("计数", systemImage: "number.square")
                }
            EventsView()
                .tabItem {
                    Label("活动日历", systemImage: "calendar")
                }
        }
    }
}
