// Swiftboard platform (MIT): CoreLocation value types. No location services in the browser port.
import Foundation
public typealias CLLocationDistance = Double
public typealias CLLocationDegrees = Double
public typealias CLLocationDirection = Double
public typealias CLLocationSpeed = Double
public typealias CLLocationAccuracy = Double
public struct CLLocationCoordinate2D: Equatable {
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public init() { latitude = 0; longitude = 0 }
    public init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) { self.latitude = latitude; self.longitude = longitude }
}
public func CLLocationCoordinate2DIsValid(_ c: CLLocationCoordinate2D) -> Bool { abs(c.latitude) <= 90 && abs(c.longitude) <= 180 }
open class CLLocation: NSObject {
    public let coordinate: CLLocationCoordinate2D
    public init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) { coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    /// Great-circle distance in meters.
    public func distance(from l: CLLocation) -> CLLocationDistance {
        let r = 6_371_000.0, d = Double.pi / 180
        let a = sin((l.coordinate.latitude - coordinate.latitude) * d / 2), b = sin((l.coordinate.longitude - coordinate.longitude) * d / 2)
        let h = a * a + cos(coordinate.latitude * d) * cos(l.coordinate.latitude * d) * b * b
        return 2 * r * asin(min(1, sqrt(h)))
    }
}
