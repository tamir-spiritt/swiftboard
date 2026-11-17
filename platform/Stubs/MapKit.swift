// Swiftboard platform (MIT): MapKit's MKDistanceFormatter (metric). Maps themselves are not ported.
import Foundation
@_exported import CoreLocation
open class MKDistanceFormatter: Formatter {
    public enum DistanceUnitStyle: Int { case `default` = 0, abbreviated, full }
    open var unitStyle: DistanceUnitStyle = .default
    open var locale: Locale = .current
    public override init() { super.init() }
    public required init?(coder: NSCoder) { nil }
    open func string(fromDistance distance: CLLocationDistance) -> String {
        let abbreviated = unitStyle == .abbreviated
        if distance < 1000 {
            let m = Int(distance.rounded())
            return abbreviated ? "\(m) m" : "\(m) \(m == 1 ? "meter" : "meters")"
        }
        let km = distance / 1000
        let s = km < 10 ? String(format: "%.1f", km) : "\(Int(km.rounded()))"
        return abbreviated ? "\(s) km" : "\(s) kilometers"
    }
}
