import Foundation
import UserNotifications

/// Manages the repeating "Tom is ready again" local notification.
///
/// Hay Day's helper Tom needs a rest after each run (2 hours by default;
/// the user can customize the interval in minutes). When the user flips
/// the switch on, we schedule one repeating local notification with that
/// interval and remember the moment it was switched on (the anchor) so
/// the UI can compute the next fire time and a countdown.
@MainActor
final class TomReminderManager: ObservableObject {
    /// Default rest interval between Tom's runs, in minutes (2 hours).
    static let defaultIntervalMinutes = 120
    /// Allowed interval range, in minutes. The lower bound is also the
    /// minimum UNTimeIntervalNotificationTrigger accepts (60 seconds)
    /// for a repeating trigger, so nothing below 1 minute is allowed.
    static let minIntervalMinutes = 1
    static let maxIntervalMinutes = 120
    static let notificationIdentifier = "tom.reminder.repeating"

    private let enabledKey = "packageCounter.tomReminder.enabled"
    private let anchorKey = "packageCounter.tomReminder.anchor"
    private let intervalKey = "packageCounter.tomReminder.intervalMinutes"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var anchor: Date?
    @Published var intervalMinutes: Int
    @Published var permissionDenied = false

    /// Current interval in seconds.
    var interval: TimeInterval { TimeInterval(intervalMinutes * 60) }

    static func clampedInterval(_ minutes: Int) -> Int {
        min(max(minutes, minIntervalMinutes), maxIntervalMinutes)
    }

    /// Formats a minute count as "2 小时" / "1 小时 30 分" / "45 分".
    static func durationText(minutes totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours) 小时 \(minutes) 分"
        } else if hours > 0 {
            return "\(hours) 小时"
        } else {
            return "\(minutes) 分"
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: intervalKey) as? Int {
            intervalMinutes = Self.clampedInterval(stored)
        } else {
            intervalMinutes = Self.defaultIntervalMinutes
        }
        var enabled = defaults.bool(forKey: enabledKey)
        var restoredAnchor: Date?
        if let timestamp = defaults.object(forKey: anchorKey) as? Double {
            restoredAnchor = Date(timeIntervalSince1970: timestamp)
        }
        // Enabled without an anchor is inconsistent (shouldn't happen, since
        // both are written together); fall back to off rather than guessing.
        if enabled && restoredAnchor == nil {
            enabled = false
            defaults.set(false, forKey: enabledKey)
        }
        isEnabled = enabled
        anchor = restoredAnchor
    }

    // MARK: - Toggle

    /// Entry point for the UI switch. Turning on is asynchronous: the
    /// notification authorization request has to resolve before `isEnabled`
    /// flips, so the UI must observe the @Published state, not the switch.
    func setEnabled(_ on: Bool) {
        if on {
            enable()
        } else {
            disable()
        }
    }

    // MARK: - Interval

    /// Changes the reminder interval (minutes, clamped to 1...120) and
    /// persists it. If the reminder is currently on, the pending request
    /// is replaced (schedule() removes it first) and the countdown
    /// restarts from now with the new interval.
    func setIntervalMinutes(_ minutes: Int) {
        intervalMinutes = Self.clampedInterval(minutes)
        if isEnabled {
            anchor = Date()
            schedule()
        }
        persist()
    }

    private func enable() {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )) ?? false
            guard granted else {
                permissionDenied = true
                isEnabled = false
                return
            }
            permissionDenied = false
            let now = Date()
            anchor = now
            isEnabled = true
            persist()
            schedule()
        }
    }

    func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.notificationIdentifier]
        )
        isEnabled = false
        anchor = nil
        permissionDenied = false
        persist()
    }

    // MARK: - Scheduling

    private func schedule() {
        let center = UNUserNotificationCenter.current()
        // Replace any stale request so there is exactly one repeating timer.
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        let content = UNMutableNotificationContent()
        content.title = "汤姆休息好了"
        content.body = "可以再让汤姆去买食材了"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Next fire / countdown

    /// The next time the notification will fire: the first anchor + n·interval
    /// strictly after `now`. The interval itself is the requirement here, so
    /// plain second arithmetic is exact (no calendar-day rounding involved).
    func nextFireDate(from now: Date = Date()) -> Date? {
        guard isEnabled, let anchor else { return nil }
        let elapsed = now.timeIntervalSince(anchor)
        guard elapsed >= 0 else { return anchor.addingTimeInterval(interval) }
        let cycles = (elapsed / interval).rounded(.down)
        return anchor.addingTimeInterval((cycles + 1) * interval)
    }

    /// Human-readable countdown to the next fire, e.g. "还有 1 小时 23 分".
    func remainingDescription(from now: Date = Date()) -> String? {
        guard let next = nextFireDate(from: now) else { return nil }
        let totalMinutes = Int((next.timeIntervalSince(now) / 60).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "还有 \(hours) 小时 \(minutes) 分"
        } else if hours > 0 {
            return "还有 \(hours) 小时"
        } else {
            return "还有 \(max(minutes, 1)) 分钟"
        }
    }

    // MARK: - Permission state

    /// Re-check authorization when the view appears, so the denied hint also
    /// shows if permission was revoked in Settings while the switch was on.
    func refreshPermissionState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .denied {
            permissionDenied = true
        } else if settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional {
            permissionDenied = false
        }
    }

    // MARK: - Persistence

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(intervalMinutes, forKey: intervalKey)
        defaults.set(isEnabled, forKey: enabledKey)
        if let anchor {
            defaults.set(anchor.timeIntervalSince1970, forKey: anchorKey)
        } else {
            defaults.removeObject(forKey: anchorKey)
        }
    }
}
