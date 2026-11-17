// Swiftboard web port: the part of Telegram's ObjC LegacyComponents the chat list uses, Facebook POP property
// animations. Like platform QuartzCore animations, a POP animation writes its final value immediately (not
// interpolated) and calls its completion after its duration.
import Foundation
import UIKit
import AsyncDisplayKit
import Display

public final class POPAnimatableProperty: NSObject {
    public var name: String = ""
    public var readBlock: ((Any?, UnsafeMutablePointer<CGFloat>?) -> Void)?
    public var writeBlock: ((Any?, UnsafePointer<CGFloat>?) -> Void)?
    public var threshold: CGFloat = 0.01
    public class func property(withName name: String, initializer: ((POPAnimatableProperty?) -> Void)?) -> Any? {
        let p = POPAnimatableProperty(); p.name = name; initializer?(p); return p
    }
    public class func property(withName name: String) -> Any? { let p = POPAnimatableProperty(); p.name = name; return p }
}

open class POPAnimation: NSObject {
    public var beginTime: CFTimeInterval = 0
    public var completionBlock: ((POPAnimation?, Bool) -> Void)?
    public var removedOnCompletion = true
    public var name: String?
    public var repeatForever = false
    public var repeatCount: Int = 0
    public var autoreverses = false
}
open class POPPropertyAnimation: POPAnimation {
    public var property: POPAnimatableProperty?
    public var fromValue: Any?
    public var toValue: Any?
    public var roundingFactor: CGFloat = 0
    public var additive = false
}
open class POPBasicAnimation: POPPropertyAnimation {
    public var duration: CFTimeInterval = 0.4
    public var timingFunction: CAMediaTimingFunction?
    public override init() { super.init() }
    public class func linear() -> POPBasicAnimation { POPBasicAnimation() }
    public class func easeInEase() -> POPBasicAnimation { POPBasicAnimation() }
}
open class POPSpringAnimation: POPPropertyAnimation {
    public var springBounciness: CGFloat = 4
    public var springSpeed: CGFloat = 12
    public var velocity: Any?
}

private var popAnimationsKey: UInt8 = 0
private final class POPAnimationBox { var animations: [String: POPAnimation] = [:] }

extension NSObject {
    private var popBox: POPAnimationBox {
        if let b = objc_getAssociatedObject(self, &popAnimationsKey) as? POPAnimationBox { return b }
        let b = POPAnimationBox(); objc_setAssociatedObject(self, &popAnimationsKey, b, .OBJC_ASSOCIATION_RETAIN_NONATOMIC); return b
    }
    public func pop_add(_ animation: POPAnimation, forKey key: String) {
        pop_removeAnimation(forKey: key)
        popBox.animations[key] = animation
        let duration = (animation as? POPBasicAnimation)?.duration ?? 0.3
        func value(_ v: Any?) -> CGFloat? {
            if let n = v as? NSNumber { return CGFloat(n.doubleValue) }
            if let d = v as? CGFloat { return d }
            if let d = v as? Double { return CGFloat(d) }
            return nil
        }
        if let a = animation as? POPPropertyAnimation, let p = a.property, var to = value(a.toValue), !a.repeatForever {
            withUnsafePointer(to: &to) { p.writeBlock?(self, $0) }
        }
        if animation.repeatForever { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + animation.beginTime + duration) { [weak self] in
            guard let self, self.popBox.animations[key] === animation else { return }
            self.popBox.animations[key] = nil
            animation.completionBlock?(animation, true)
        }
    }
    public func pop_removeAnimation(forKey key: String) {
        if let a = popBox.animations.removeValue(forKey: key) { a.completionBlock?(a, false) }
    }
    public func pop_removeAllAnimations() { for k in Array(popBox.animations.keys) { pop_removeAnimation(forKey: k) } }
    public func pop_animation(forKey key: String) -> Any? { popBox.animations[key] }
    public func pop_animationKeys() -> [Any]? { Array(popBox.animations.keys) }
}
