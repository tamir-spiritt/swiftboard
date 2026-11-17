// Swiftboard (MIT): AudioToolbox stand-in (system sounds are silent in the browser port).
import Foundation
public typealias SystemSoundID = UInt32
public func AudioServicesPlaySystemSound(_ id: SystemSoundID) {}
public func AudioServicesPlayAlertSound(_ id: SystemSoundID) {}
public let kSystemSoundID_Vibrate: SystemSoundID = 4095
