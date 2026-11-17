// Swiftboard (MIT): CoreHaptics stand-in. The browser has no haptic engine, so creating one throws.
import Foundation
public struct CHHapticError: Error { public init() {} }
public final class CHHapticEventParameter {
    public struct ID: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let hapticIntensity = ID(rawValue: "HapticIntensity"); public static let hapticSharpness = ID(rawValue: "HapticSharpness")
        public static let attackTime = ID(rawValue: "AttackTime"); public static let decayTime = ID(rawValue: "DecayTime"); public static let releaseTime = ID(rawValue: "ReleaseTime") }
    public init(parameterID: ID, value: Float) {}
}
public final class CHHapticDynamicParameter {
    public struct ID: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let hapticIntensityControl = ID(rawValue: "HapticIntensityControl") }
    public init(parameterID: ID, value: Float, relativeTime: TimeInterval) {}
}
public final class CHHapticEvent {
    public struct EventType: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let hapticTransient = EventType(rawValue: "HapticTransient"); public static let hapticContinuous = EventType(rawValue: "HapticContinuous") }
    public init(eventType: EventType, parameters: [CHHapticEventParameter], relativeTime: TimeInterval, duration: TimeInterval) {}
    public init(eventType: EventType, parameters: [CHHapticEventParameter], relativeTime: TimeInterval) {}
}
public final class CHHapticPattern {
    public init(events: [CHHapticEvent], parameters: [CHHapticDynamicParameter]) throws {}
}
public protocol CHHapticPatternPlayer: AnyObject {
    func start(atTime time: TimeInterval) throws
    func stop(atTime time: TimeInterval) throws
}
public let CHHapticTimeImmediate: TimeInterval = 0
public final class CHHapticEngine {
    public static func capabilitiesForHardware() -> Capabilities { Capabilities() }
    public struct Capabilities { public var supportsHaptics: Bool { false }; public var supportsAudio: Bool { false } }
    public var isAutoShutdownEnabled = false
    public var playsHapticsOnly = true
    public var stoppedHandler: ((Int) -> Void)?
    public var resetHandler: (() -> Void)?
    public init() throws { throw CHHapticError() }
    public func start() throws {}
    public func start(completionHandler: ((Error?) -> Void)? = nil) { completionHandler?(CHHapticError()) }
    public func stop(completionHandler: ((Error?) -> Void)? = nil) { completionHandler?(nil) }
    public func makePlayer(with pattern: CHHapticPattern) throws -> CHHapticPatternPlayer { throw CHHapticError() }
}
