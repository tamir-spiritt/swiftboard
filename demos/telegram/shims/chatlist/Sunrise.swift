// Swiftboard web port: Telegram's ObjC EDSunriseSet (automatic night theme by sunset). The web build reports a fixed
// 06:00-18:00 day, enough for theme selection.
import Foundation
public final class EDSunriseSet: NSObject {
    let date: Date
    public init?(date: Date, timezone: TimeZone, latitude: Double, longitude: Double) { self.date = date }
    private func at(_ h: Int) -> Date { Calendar(identifier: .gregorian).date(bySettingHour: h, minute: 0, second: 0, of: date) ?? date }
    public var sunrise: Date { at(6) }
    public var sunset: Date { at(18) }
    public var localSunrise: DateComponents { DateComponents(hour: 6, minute: 0) }
    public var localSunset: DateComponents { DateComponents(hour: 18, minute: 0) }
}
