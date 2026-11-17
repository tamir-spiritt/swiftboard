// Swiftboard web port: Swift stand-in for Telegram's ObjCRuntimeUtils (ObjC module). Swizzling has no meaning
// without the ObjC runtime; associated objects map onto WebCompat's.
import Foundation
import QuartzCore

public enum NSObjectAssociationPolicy: Int { case retain = 0, copy = 1 }
public let NSObjectAssociationPolicyRetain = NSObjectAssociationPolicy.retain
public let NSObjectAssociationPolicyCopy = NSObjectAssociationPolicy.copy

public final class RuntimeUtils: NSObject {
    public static func swizzleInstanceMethod(ofClass targetClass: AnyClass, currentSelector: Selector, newSelector: Selector) {}
    public static func swizzleInstanceMethod(ofClass targetClass: AnyClass, currentSelector: Selector, withAnotherClass anotherClass: AnyClass, newSelector: Selector) {}
    public static func swizzleClassMethod(ofClass targetClass: AnyClass, currentSelector: Selector, newSelector: Selector) {}
    public static func getMethodOf(_ targetClass: AnyClass, selector: Selector) -> UnsafeMutableRawPointer? { nil }
    public static func replaceMethodImplementation(of targetClass: AnyClass, selector: Selector, replacement: OpaquePointer) {}
    public static func makeLayerHostCopy(_ another: CALayer) -> CALayer { let l = CALayer(); l.webCopyState(from: another); return l }
}

extension NSObject {
    public func setAssociatedObject(_ object: Any?, forKey key: UnsafeRawPointer) {
        objc_setAssociatedObject(self, key, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    public func setAssociatedObject(_ object: Any?, forKey key: UnsafeRawPointer, associationPolicy: NSObjectAssociationPolicy) {
        objc_setAssociatedObject(self, key, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    public func associatedObject(forKey key: UnsafeRawPointer) -> Any? { objc_getAssociatedObject(self, key) }
    public func checkIsKind(of targetClass: AnyClass) -> Bool { isKind(of: targetClass) }
    public func setClass(_ newClass: AnyClass) {}
    public static func getIvarList(_ classValue: AnyClass) -> [String] { [] }
    public func getIvarValue(_ name: String) -> Any? { nil }
    public func floatValue(forKeyPath keyPath: String) -> NSNumber? { value(forKeyPath: keyPath) as? NSNumber }
}

public func makeSelectorFromString(_ string: String) -> Selector { Selector(string) }
