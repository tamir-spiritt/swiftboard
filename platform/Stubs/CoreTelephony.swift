// Swiftboard platform (MIT): Apple's CoreTelephony radio-technology API. A browser has no cellular radio.
import Foundation
public let CTRadioAccessTechnologyGPRS = "CTRadioAccessTechnologyGPRS"
public let CTRadioAccessTechnologyEdge = "CTRadioAccessTechnologyEdge"
public let CTRadioAccessTechnologyWCDMA = "CTRadioAccessTechnologyWCDMA"
public let CTRadioAccessTechnologyHSDPA = "CTRadioAccessTechnologyHSDPA"
public let CTRadioAccessTechnologyHSUPA = "CTRadioAccessTechnologyHSUPA"
public let CTRadioAccessTechnologyCDMA1x = "CTRadioAccessTechnologyCDMA1x"
public let CTRadioAccessTechnologyCDMAEVDORev0 = "CTRadioAccessTechnologyCDMAEVDORev0"
public let CTRadioAccessTechnologyCDMAEVDORevA = "CTRadioAccessTechnologyCDMAEVDORevA"
public let CTRadioAccessTechnologyCDMAEVDORevB = "CTRadioAccessTechnologyCDMAEVDORevB"
public let CTRadioAccessTechnologyeHRPD = "CTRadioAccessTechnologyeHRPD"
public let CTRadioAccessTechnologyLTE = "CTRadioAccessTechnologyLTE"
public let CTRadioAccessTechnologyNRNSA = "CTRadioAccessTechnologyNRNSA"
public let CTRadioAccessTechnologyNR = "CTRadioAccessTechnologyNR"
extension NSNotification.Name {
    public static let CTServiceRadioAccessTechnologyDidChange = NSNotification.Name("CTServiceRadioAccessTechnologyDidChange")
}
public final class CTTelephonyNetworkInfo: NSObject {
    public override init() {}
    public var serviceCurrentRadioAccessTechnology: [String: String]? { nil }
    public var currentRadioAccessTechnology: String? { nil }
}
