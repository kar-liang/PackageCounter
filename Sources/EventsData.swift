import Foundation

/// Bundled snapshot of the current events week, shown immediately on launch
/// and used whenever the remote events.json cannot be fetched.
enum EventsData {
    static let fallbackWeek = EventsWeek(
        weekLabel: "第48周",
        rangeLabel: "2026-11-23 至 2026-11-29",
        days: [
            EventDay(date: "2026-11-23", weekday: "周一", title: "幸运转盘",
                     detail: "奖励包含扩地许可证"),
            EventDay(date: "2026-11-24", weekday: "周二", title: "卡车订单双倍经验",
                     detail: "翻倍的是经验不是金币；活动 16:00 开始、次日 16:00 结束，金币照常"),
            EventDay(date: "2026-11-25", weekday: "周三", title: "生产加速",
                     detail: "随机 3 个机器，耗时 -20%"),
            EventDay(date: "2026-11-26", weekday: "周四", title: "农场访客双倍金币",
                     detail: "作物建议主推小麦（访客固定价 28/10 个，双倍 56/10 个，高于路边摊满价 36/10 个）；果树备选桃子；玉米别卖访客"),
            EventDay(date: "2026-11-27", weekday: "周五", title: "渔业加速",
                     detail: "龙虾池 + 鱼饵机耗时 -30%；周四提前做好龙虾陷阱、把鱼饵机排满"),
            EventDay(date: "2026-11-28", weekday: "周六", title: "小镇访客奖励",
                     detail: "小镇访客掉落货仓、粮仓建材"),
            EventDay(date: "2026-11-29", weekday: "周日", title: "饲料加速",
                     detail: "随机 3 种动物饲料产出速度翻倍；周六备好饲料原料，周日集中磨被选中的 3 种"),
        ],
        derby: "休闲兔子德比（周二 16:00 至下周一 16:00）",
        ongoing: [
            OngoingEvent(name: "Tiny Sail", dates: "11月21日–24日"),
            OngoingEvent(name: "Design Festival", dates: "11月18日–30日"),
            OngoingEvent(name: "Neighbourhood Nurture Event", dates: "11月9日–12月30日"),
        ],
        updatedAt: "2026-11-23"
    )
}
