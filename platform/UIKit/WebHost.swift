// Swiftboard UIKit (MIT): the exports a browser host drives (see web/uikit-host.js).
//   uikit_frame() -> ptr, uikit_frame_len() -> bytes : JSON display list of the key window (layout + display flushed)
//   uikit_pointer(id, phase, x, y)                   : touch input in window points (phase 0 began 1 moved 2 ended 3 cancelled)
//   uikit_wheel(x, y, dx, dy)                        : scrolls the scroll view under the point
//   uikit_set_screen(w, h, scale)                    : screen size in points and pixel ratio (call before the app starts)
//   webRunLoopTick() (WebCompat)                      : run due work; returns ns to next timer, 0 more work, -1 idle
import Foundation

public enum WebHost {
    nonisolated(unsafe) static var frameBytes: [UInt8] = []
    nonisolated(unsafe) public static var annotate: ((CALayer) -> String?)?
    /// Bumped by input and by apps when state changes; the host repaints when it changes.
    nonisolated(unsafe) public static var generation = 0

    public static func frameJSON() -> String {
        CALayer.webFlush()
        let windows = UIApplication.shared.windows.filter { !$0.isHidden }
        let parts = windows.map { WebDisplayList.json($0.layer, annotate: annotate) }
        return "[" + parts.joined(separator: ",") + "]"
    }
}

@_cdecl("uikit_frame")
public func uikit_frame() -> UnsafePointer<UInt8>? {
    WebHost.frameBytes = Array(WebHost.frameJSON().utf8)
    return WebHost.frameBytes.withUnsafeBufferPointer { $0.baseAddress }
}
@_cdecl("uikit_frame_len")
public func uikit_frame_len() -> Int32 { Int32(WebHost.frameBytes.count) }

@_cdecl("uikit_generation")
public func uikit_generation() -> Int32 { Int32(truncatingIfNeeded: WebHost.generation) }

@_cdecl("uikit_pointer")
public func uikit_pointer(_ id: Int32, _ phase: Int32, _ x: Double, _ y: Double) {
    guard let w = UIApplication.shared.keyWindow else { return }
    WebEventDispatch.pointer(id: Int(id), phase: Int(phase), x: x, y: y, window: w)
    WebHost.generation += 1
}

@_cdecl("uikit_wheel")
public func uikit_wheel(_ x: Double, _ y: Double, _ dx: Double, _ dy: Double) {
    guard let w = UIApplication.shared.keyWindow else { return }
    // The nearest enabled scroll view that is the hit view, an ancestor, or a direct subview of an ancestor covering
    // the point (lists like Telegram's ListView keep their scroller as a sibling of the cells).
    let p = CGPoint(x: x, y: y)
    var v = w.hitTest(p, with: nil)
    var found: UIScrollView?
    while let c = v, found == nil {
        if let s = c as? UIScrollView, s.isScrollEnabled { found = s; break }
        found = c.subviews.reversed().first { sub in
            guard let s = sub as? UIScrollView, s.isScrollEnabled, !s.isHidden || s.panGestureRecognizer.view !== s else { return false }
            return s.frame.contains(c.convert(p, from: w))
        } as? UIScrollView
        v = c.superview
    }
    guard let s = found else { return }
    let inset = s.adjustedContentInset
    let maxY = max(-inset.top, s.contentSize.height + inset.bottom - s.bounds.height)
    let maxX = max(-inset.left, s.contentSize.width + inset.right - s.bounds.width)
    var o = s.contentOffset
    o.y = min(max(o.y + CGFloat(dy), -inset.top), maxY)
    if s.contentSize.width > s.bounds.width { o.x = min(max(o.x + CGFloat(dx), -inset.left), maxX) }
    if o != s.contentOffset {
        s.delegate?.scrollViewWillBeginDragging(s)
        s.contentOffset = o
        var target = o
        withUnsafeMutablePointer(to: &target) { s.delegate?.scrollViewWillEndDragging(s, withVelocity: .zero, targetContentOffset: $0) }
        s.delegate?.scrollViewDidEndDragging(s, willDecelerate: false)
        s.delegate?.scrollViewDidEndDecelerating(s)
    }
    WebHost.generation += 1
}

@_cdecl("uikit_set_screen")
public func uikit_set_screen(_ w: Double, _ h: Double, _ scale: Double) {
    setvbuf(stdout, nil, _IOLBF, 0) // print() lines reach the host console immediately
    UIScreen.webSize = CGSize(width: w, height: h)
    UIScreen.webScale = CGFloat(scale)
}

@_cdecl("uikit_debug")
public func uikit_debug(_ on: Int32) { WebEventDispatch.debug = on != 0 }
