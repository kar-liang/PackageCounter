import Foundation
import SwiftUI

final class Store: ObservableObject {
    @Published var accounts: [PackageAccount] = [] {
        didSet { save() }
    }
    @Published var selectedAccountID: UUID? {
        didSet { save() }
    }

    private let storageKey = "packageCounter.state.v1"
    private var isLoading = false

    init() {
        isLoading = true
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let state = try? JSONDecoder().decode(PersistedState.self, from: data),
           !state.accounts.isEmpty {
            accounts = state.accounts
            selectedAccountID = state.selectedAccountID ?? state.accounts.first?.id
        } else {
            let seed = Store.seedAccounts()
            accounts = seed
            selectedAccountID = seed.first?.id
        }
        isLoading = false
        save()
    }

    // MARK: - Seed data (first launch only)

    static func seedAccounts() -> [PackageAccount] {
        let start = Day.makeDate(year: 2026, month: 11, day: 21)
        let account1 = PackageAccount(
            name: "账号1",
            startDate: start,
            totalDays: 30,
            shippedDayKeys: [
                Day.key(for: Day.makeDate(year: 2026, month: 11, day: 21)),
                Day.key(for: Day.makeDate(year: 2026, month: 11, day: 22)),
                Day.key(for: Day.makeDate(year: 2026, month: 11, day: 23)),
            ]
        )
        let account2 = PackageAccount(
            name: "账号2",
            startDate: nil,
            totalDays: 30,
            shippedDayKeys: []
        )
        return [account1, account2]
    }

    // MARK: - Selection

    var selectedAccount: PackageAccount? {
        get {
            if let selectedAccountID,
               let account = accounts.first(where: { $0.id == selectedAccountID }) {
                return account
            }
            return accounts.first
        }
    }

    func select(_ account: PackageAccount) {
        selectedAccountID = account.id
    }

    // MARK: - Mutations

    private func update(_ id: UUID, _ mutate: (inout PackageAccount) -> Void) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        var copy = accounts
        mutate(&copy[index])
        accounts = copy
    }

    func addAccount() {
        let account = PackageAccount(name: "账号\(accounts.count + 1)", startDate: nil, totalDays: 30)
        accounts.append(account)
        selectedAccountID = account.id
    }

    func markTodayShipped(accountID: UUID) {
        let today = Date()
        update(accountID) { account in
            guard account.contains(today), !account.isShipped(today) else { return }
            account.shippedDayKeys.insert(Day.key(for: today))
        }
    }

    func undoLastShipment(accountID: UUID) {
        update(accountID) { account in
            guard let last = account.shippedDates.last else { return }
            account.shippedDayKeys.remove(Day.key(for: last))
        }
    }

    func toggleShipped(accountID: UUID, date: Date) {
        update(accountID) { account in
            let key = Day.key(for: date)
            if account.shippedDayKeys.contains(key) {
                account.shippedDayKeys.remove(key)
            } else {
                account.shippedDayKeys.insert(key)
            }
        }
    }

    func updateSettings(accountID: UUID, name: String, startDate: Date?, totalDays: Int) {
        update(accountID) { account in
            account.name = name
            account.startDate = startDate.map { Day.startOfDay($0) }
            account.totalDays = totalDays
        }
    }

    // MARK: - Persistence

    private func save() {
        guard !isLoading else { return }
        let state = PersistedState(accounts: accounts, selectedAccountID: selectedAccountID)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
