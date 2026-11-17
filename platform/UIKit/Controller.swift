// Swiftboard UIKit (MIT): view controllers, navigation items, application and scenes.
import Foundation

public enum UIModalPresentationStyle: Int { case fullScreen = 0, pageSheet, formSheet, currentContext, custom, overFullScreen, overCurrentContext, popover, none = -1, automatic = -2 }
public enum UIModalTransitionStyle: Int { case coverVertical, flipHorizontal, crossDissolve, partialCurl }

public protocol UIViewControllerTransitionCoordinatorContext: AnyObject {
    var isAnimated: Bool { get }
    var isCancelled: Bool { get }
    var transitionDuration: TimeInterval { get }
    var containerView: UIView { get }
}
public protocol UIViewControllerTransitionCoordinator: UIViewControllerTransitionCoordinatorContext {
    @discardableResult
    func animate(alongsideTransition animation: ((UIViewControllerTransitionCoordinatorContext) -> Void)?, completion: ((UIViewControllerTransitionCoordinatorContext) -> Void)?) -> Bool
}
final class WebTransitionCoordinator: UIViewControllerTransitionCoordinator {
    let containerView: UIView
    init(_ v: UIView) { containerView = v }
    var isAnimated: Bool { false }
    var isCancelled: Bool { false }
    var transitionDuration: TimeInterval { 0 }
    func animate(alongsideTransition animation: ((UIViewControllerTransitionCoordinatorContext) -> Void)?, completion: ((UIViewControllerTransitionCoordinatorContext) -> Void)?) -> Bool {
        animation?(self); completion?(self); return true
    }
}

open class UIViewController: UIResponder, UITraitEnvironment {
    private var _view: UIView?
    open var view: UIView! {
        get {
            if _view == nil { loadView(); _view?.webViewController = self; viewDidLoad() }
            return _view
        }
        set { _view = newValue; newValue?.webViewController = self }
    }
    open var viewIfLoaded: UIView? { _view }
    open var isViewLoaded: Bool { _view != nil }
    open var title: String? { didSet { navigationItem.title = title } }
    public private(set) lazy var navigationItem = UINavigationItem(title: "")
    open var tabBarItem: UITabBarItem! = UITabBarItem()
    open var toolbarItems: [UIBarButtonItem]?
    public private(set) weak var parent: UIViewController?
    public private(set) var children: [UIViewController] = []
    private var _presented: UIViewController?
    private weak var _presenting: UIViewController?
    open var presentedViewController: UIViewController? { _presented }
    open var presentingViewController: UIViewController? { _presenting }
    public func webSetPresented(_ vc: UIViewController?) { _presented = vc }
    public func webSetPresenting(_ vc: UIViewController?) { _presenting = vc }
    open var modalPresentationStyle: UIModalPresentationStyle = .automatic
    open var modalTransitionStyle: UIModalTransitionStyle = .coverVertical
    open var definesPresentationContext = false
    open var providesPresentationContextTransitionStyle = false
    open var isModalInPresentation = false
    open var modalPresentationCapturesStatusBarAppearance = false
    open var additionalSafeAreaInsets: UIEdgeInsets = .zero
    open var edgesForExtendedLayout: UIRectEdge = .all
    open var extendedLayoutIncludesOpaqueBars = false
    open var automaticallyAdjustsScrollViewInsets = true
    open var preferredContentSize: CGSize = .zero
    open var overrideUserInterfaceStyle: UIUserInterfaceStyle = .unspecified
    open var restorationIdentifier: String?
    open var hidesBottomBarWhenPushed = false
    open var viewRespectsSystemMinimumLayoutMargins = true
    open var transitioningDelegate: AnyObject?
    public internal(set) var isBeingPresented = false
    public internal(set) var isBeingDismissed = false
    public internal(set) var isMovingToParent = false
    public internal(set) var isMovingFromParent = false
    open var nibName: String? { nil }
    open var nibBundle: Bundle? { nil }

    public init(nibName: String?, bundle: Bundle?) { super.init() }
    public required init?(coder: NSCoder) { super.init() }
    public override convenience init() { self.init(nibName: nil, bundle: nil) }

    open func loadView() { view = UIView(frame: UIScreen.main.bounds) }
    open func loadViewIfNeeded() { _ = view }
    open func viewDidLoad() {}
    open func viewWillAppear(_ animated: Bool) {}
    open func viewDidAppear(_ animated: Bool) {}
    open func viewWillDisappear(_ animated: Bool) {}
    open func viewDidDisappear(_ animated: Bool) {}
    open func viewWillLayoutSubviews() {}
    open func viewDidLayoutSubviews() {}
    open func viewLayoutMarginsDidChange() {}
    open func viewSafeAreaInsetsDidChange() {}
    open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {}
    open func didReceiveMemoryWarning() {}
    open func updateViewConstraints() {}
    open var traitCollection: UITraitCollection { _view?.traitCollection ?? UITraitCollection.current }
    open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {}
    open func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {}
    open override var next: UIResponder? { _view?.superview ?? presentingViewController }

    // containment
    open func addChild(_ child: UIViewController) {
        child.removeFromParent()
        child.willMove(toParent: self)
        children.append(child); child.parent = self
    }
    open func removeFromParent() {
        guard let p = parent else { return }
        p.children.removeAll { $0 === self }
        parent = nil
    }
    open func willMove(toParent parent: UIViewController?) {}
    open func didMove(toParent parent: UIViewController?) {}
    open var shouldAutomaticallyForwardAppearanceMethods: Bool { true }
    open func beginAppearanceTransition(_ isAppearing: Bool, animated: Bool) { if isAppearing { viewWillAppear(animated) } else { viewWillDisappear(animated) } }
    open func endAppearanceTransition() {}
    open func setOverrideTraitCollection(_ t: UITraitCollection?, forChild child: UIViewController) {}

    // presentation
    open func present(_ vc: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        _presented = vc
        vc._presenting = self
        let host = view.window ?? view!
        vc.view.frame = host.bounds
        vc.beginAppearanceTransition(true, animated: flag)
        host.addSubview(vc.view)
        vc.viewDidAppear(flag)
        completion?()
    }
    open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        let target = presentedViewController ?? self
        target.viewWillDisappear(flag)
        target.viewIfLoaded?.removeFromSuperview()
        target.viewDidDisappear(flag)
        target._presenting?._presented = nil
        target._presenting = nil
        completion?()
    }
    open func show(_ vc: UIViewController, sender: Any?) { navigationController?.pushViewController(vc, animated: true) ?? present(vc, animated: true) }
    open var navigationController: UINavigationController? {
        var p = parent
        while let c = p { if let n = c as? UINavigationController { return n }; p = c.parent }
        return nil
    }
    open var transitionCoordinator: UIViewControllerTransitionCoordinator? { nil }
    open var splitViewController: UIViewController? { nil }
    open var tabBarController: UIViewController? { nil }

    // status bar & system
    open var preferredStatusBarStyle: UIStatusBarStyle { .default }
    open var prefersStatusBarHidden: Bool { false }
    open var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
    open var childForStatusBarStyle: UIViewController? { nil }
    open var childForStatusBarHidden: UIViewController? { nil }
    open var childForHomeIndicatorAutoHidden: UIViewController? { nil }
    open var childForScreenEdgesDeferringSystemGestures: UIViewController? { nil }
    open var prefersHomeIndicatorAutoHidden: Bool { false }
    open var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { [] }
    open var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    open var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }
    open var shouldAutorotate: Bool { true }
    open func setNeedsStatusBarAppearanceUpdate() {}
    open func setNeedsUpdateOfHomeIndicatorAutoHidden() {}
    open func setNeedsUpdateOfScreenEdgesDeferringSystemGestures() {}
    open func setNeedsUpdateOfSupportedInterfaceOrientations() {}
    public class func attemptRotationToDeviceOrientation() {}
}

open class UINavigationController: UIViewController {
    open var viewControllers: [UIViewController] = []
    open weak var delegate: AnyObject?
    open var topViewController: UIViewController? { viewControllers.last }
    open var visibleViewController: UIViewController? { presentedViewController ?? topViewController }
    open var isNavigationBarHidden = false
    open var isToolbarHidden = true
    public let navigationBar = UINavigationBar()
    open var interactivePopGestureRecognizer: UIGestureRecognizer? { nil }
    public init(rootViewController: UIViewController) { super.init(nibName: nil, bundle: nil); pushViewController(rootViewController, animated: false) }
    public init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) { super.init(nibName: nil, bundle: nil) }
    public override init(nibName: String?, bundle: Bundle?) { super.init(nibName: nibName, bundle: bundle) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open func pushViewController(_ vc: UIViewController, animated: Bool) {
        addChild(vc)
        viewControllers.append(vc)
        if isViewLoaded { vc.view.frame = view.bounds; view.addSubview(vc.view) }
        vc.didMove(toParent: self)
    }
    @discardableResult open func popViewController(animated: Bool) -> UIViewController? {
        guard viewControllers.count > 1, let top = viewControllers.popLast() else { return nil }
        top.viewIfLoaded?.removeFromSuperview(); top.removeFromParent()
        return top
    }
    @discardableResult open func popToViewController(_ vc: UIViewController, animated: Bool) -> [UIViewController]? {
        guard let i = viewControllers.firstIndex(where: { $0 === vc }) else { return nil }
        let removed = Array(viewControllers[(i + 1)...])
        removed.forEach { $0.viewIfLoaded?.removeFromSuperview(); $0.removeFromParent() }
        viewControllers = Array(viewControllers[...i])
        return removed
    }
    @discardableResult open func popToRootViewController(animated: Bool) -> [UIViewController]? {
        guard let f = viewControllers.first else { return nil }
        return popToViewController(f, animated: animated)
    }
    open func setViewControllers(_ vcs: [UIViewController], animated: Bool) {
        viewControllers.forEach { $0.viewIfLoaded?.removeFromSuperview(); $0.removeFromParent() }
        viewControllers = []
        vcs.forEach { pushViewController($0, animated: false) }
    }
    open func setNavigationBarHidden(_ h: Bool, animated: Bool) { isNavigationBarHidden = h }
    open func setToolbarHidden(_ h: Bool, animated: Bool) { isToolbarHidden = h }
}
open class UINavigationBar: UIView {
    open var barStyle = 0
    open var isTranslucent = true
    open var barTintColor: UIColor?
    open var titleTextAttributes: [NSAttributedString.Key: Any]?
    open var prefersLargeTitles = false
}

/// Property-change observers (the ObjC original relies on swizzled setters; Telegram's runtime utils listen here).
public final class WebObservers {
    private var next = 0
    private var list: [(Int, (String) -> Void)] = []
    public init() {}
    @discardableResult public func add(_ f: @escaping (String) -> Void) -> Int { next += 1; list.append((next, f)); return next }
    public func remove(_ key: Int) { list.removeAll { $0.0 == key } }
    public func notify(_ property: String) { for (_, f) in list { f(property) } }
}

open class UIBarItem: NSObject {
    public let webObservers = WebObservers()
    open var isEnabled = true { didSet { webObservers.notify("enabled") } }
    open var title: String? { didSet { webObservers.notify("title") } }
    open var image: UIImage? { didSet { webObservers.notify("image") } }
    open var landscapeImagePhone: UIImage?
    open var largeContentSizeImage: UIImage?
    open var imageInsets: UIEdgeInsets = .zero
    open var tag = 0
    open var accessibilityLabel: String?
    open var accessibilityHint: String?
    open var accessibilityIdentifier: String?
    open var accessibilityTraits: UIAccessibilityTraits = []
    open var isAccessibilityElement = false
    private var titleAttributes: [UInt: [NSAttributedString.Key: Any]] = [:]
    open func setTitleTextAttributes(_ a: [NSAttributedString.Key: Any]?, for s: UIControl.State) { titleAttributes[s.rawValue] = a }
    open func titleTextAttributes(for s: UIControl.State) -> [NSAttributedString.Key: Any]? { titleAttributes[s.rawValue] }
    public override init() {}
}
open class UIBarButtonItem: UIBarItem {
    public enum Style: Int { case plain, bordered, done, prominent }
    public enum SystemItem: Int { case done, cancel, edit, save, add, flexibleSpace, fixedSpace, compose, reply, action, organize, bookmarks, search, refresh, stop, camera, trash, play, pause, rewind, fastForward, undo, redo, pageCurl, close }
    open var style: Style = .plain
    open var width: CGFloat = 0
    open var customView: UIView?
    open var action: Selector?
    open weak var target: AnyObject?
    open var tintColor: UIColor?
    open var menu: UIMenu?
    open var primaryAction: UIAction?
    open var isSelected = false
    open var isHidden = false
    public private(set) var systemItem: SystemItem?
    public override init() { super.init() }
    public convenience init(title: String?, style: Style, target: Any?, action: Selector?) {
        self.init(); self.title = title; self.style = style; self.target = target as AnyObject?; self.action = action
    }
    public convenience init(image: UIImage?, style: Style, target: Any?, action: Selector?) {
        self.init(); self.image = image; self.style = style; self.target = target as AnyObject?; self.action = action
    }
    public convenience init(barButtonSystemItem item: SystemItem, target: Any?, action: Selector?) {
        self.init(); systemItem = item; self.target = target as AnyObject?; self.action = action
    }
    public convenience init(customView: UIView) { self.init(); self.customView = customView }
    public convenience init(title: String? = nil, image: UIImage? = nil, primaryAction: UIAction? = nil, menu: UIMenu? = nil) {
        self.init(); self.title = title; self.image = image; self.primaryAction = primaryAction; self.menu = menu
    }
    public class func fixedSpace(_ w: CGFloat) -> UIBarButtonItem { let b = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil); b.width = w; return b }
    public class func flexibleSpace() -> UIBarButtonItem { UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil) }
}
open class UITabBarItem: UIBarItem {
    open var selectedImage: UIImage? { didSet { webObservers.notify("selectedImage") } }
    open var badgeValue: String? { didSet { webObservers.notify("badgeValue") } }
    open var badgeColor: UIColor?
    open var titlePositionAdjustment: UIOffset = .zero
    public override init() { super.init() }
    public convenience init(title: String?, image: UIImage?, tag: Int) { self.init(); self.title = title; self.image = image; self.tag = tag }
    public convenience init(title: String?, image: UIImage?, selectedImage: UIImage?) { self.init(); self.title = title; self.image = image; self.selectedImage = selectedImage }
}
open class UINavigationItem: NSObject {
    public enum LargeTitleDisplayMode: Int { case automatic, always, never, inline }
    public let webObservers = WebObservers()
    open var title: String? { didSet { webObservers.notify("title") } }
    open var titleView: UIView? { didSet { webObservers.notify("titleView") } }
    open var prompt: String?
    open var backBarButtonItem: UIBarButtonItem? { didSet { webObservers.notify("backBarButtonItem") } }
    open var backButtonTitle: String?
    open var hidesBackButton = false
    open var leftItemsSupplementBackButton = false
    open var leftBarButtonItems: [UIBarButtonItem]? { didSet { webObservers.notify("leftBarButtonItems") } }
    open var rightBarButtonItems: [UIBarButtonItem]? { didSet { webObservers.notify("rightBarButtonItems") } }
    open var largeTitleDisplayMode: LargeTitleDisplayMode = .automatic
    open var searchController: AnyObject?
    open var hidesSearchBarWhenScrolling = true
    open var leftBarButtonItem: UIBarButtonItem? { get { leftBarButtonItems?.first } set { leftBarButtonItems = newValue.map { [$0] } } }
    open var rightBarButtonItem: UIBarButtonItem? { get { rightBarButtonItems?.first } set { rightBarButtonItems = newValue.map { [$0] } } }
    public init(title: String) { self.title = title }
    public override convenience init() { self.init(title: "") }
    open func setHidesBackButton(_ h: Bool, animated: Bool) { hidesBackButton = h }
    open func setLeftBarButton(_ i: UIBarButtonItem?, animated: Bool) { leftBarButtonItem = i }
    open func setRightBarButton(_ i: UIBarButtonItem?, animated: Bool) { rightBarButtonItem = i }
    open func setLeftBarButtonItems(_ i: [UIBarButtonItem]?, animated: Bool) { leftBarButtonItems = i }
    open func setRightBarButtonItems(_ i: [UIBarButtonItem]?, animated: Bool) { rightBarButtonItems = i }
}

// MARK: application & scenes

public protocol UIApplicationDelegate: AnyObject {}

open class UIApplication: UIResponder {
    public enum State: Int { case active, inactive, background }
    public struct OpenExternalURLOptionsKey: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let universalLinksOnly = OpenExternalURLOptionsKey(rawValue: "UIApplicationOpenURLOptionUniversalLinksOnly") }
    public struct LaunchOptionsKey: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
    nonisolated(unsafe) public static let shared = UIApplication()
    var webWindows: [WeakWindow] = []
    open weak var delegate: UIApplicationDelegate?
    public var windows: [UIWindow] { webWindows.compactMap { $0.window } }
    public var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } ?? windows.first }
    public var applicationState: State { .active }
    public var isIdleTimerDisabled = false
    public var isStatusBarHidden = false
    public var statusBarStyle: UIStatusBarStyle = .default
    public var statusBarFrame: CGRect { CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 47) }
    public var statusBarOrientation: UIInterfaceOrientation { .portrait }
    public var applicationIconBadgeNumber = 0
    public var isNetworkActivityIndicatorVisible = false
    public var userInterfaceLayoutDirection: UIUserInterfaceLayoutDirection { .leftToRight }
    public var preferredContentSizeCategory: UIContentSizeCategory { .large }
    public var connectedScenes: Set<UIScene> { [UIWindowScene.web] }
    public var openSessions: Set<NSObject> { [] }
    public var supportsAlternateIcons: Bool { false }
    public var alternateIconName: String? { nil }
    public var isRegisteredForRemoteNotifications: Bool { false }
    public var backgroundTimeRemaining: TimeInterval { .greatestFiniteMagnitude }
    public var isProtectedDataAvailable: Bool { true }
    public var shortcutItems: [AnyObject]?
    public var isIgnoringInteractionEvents: Bool { false }
    public override init() { super.init() }
    @discardableResult open func sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        var t: AnyObject? = target as AnyObject?
        if t == nil { t = (UIResponder.webFirstResponder?.target(forAction: action, withSender: sender)).map { $0 as AnyObject } }
        guard let t else { return false }
        action.perform(on: t, with: sender, with: event)
        return true
    }
    open func sendEvent(_ event: UIEvent) { keyWindow?.sendEvent(event) }
    public func open(_ url: URL, options: [OpenExternalURLOptionsKey: Any] = [:], completionHandler: ((Bool) -> Void)? = nil) { completionHandler?(false) }
    public func canOpenURL(_ url: URL) -> Bool { false }
    public func beginIgnoringInteractionEvents() {}
    public func endIgnoringInteractionEvents() {}
    public func registerForRemoteNotifications() {}
    public func unregisterForRemoteNotifications() {}
    public func beginBackgroundTask(withName name: String?, expirationHandler: (() -> Void)? = nil) -> UIBackgroundTaskIdentifier { UIBackgroundTaskIdentifier(rawValue: 1) }
    public func beginBackgroundTask(expirationHandler: (() -> Void)? = nil) -> UIBackgroundTaskIdentifier { UIBackgroundTaskIdentifier(rawValue: 1) }
    public func endBackgroundTask(_ id: UIBackgroundTaskIdentifier) {}
    public func setStatusBarStyle(_ s: UIStatusBarStyle, animated: Bool) { statusBarStyle = s }
    public func setStatusBarHidden(_ h: Bool, with a: UIStatusBarAnimation) { isStatusBarHidden = h }
    public func setAlternateIconName(_ n: String?, completionHandler: ((Error?) -> Void)? = nil) { completionHandler?(nil) }
    public func requestSceneSessionActivation(_ s: AnyObject?, userActivity: AnyObject?, options: AnyObject?, errorHandler: ((Error) -> Void)? = nil) {}
    public static let didBecomeActiveNotification = Notification.Name("UIApplicationDidBecomeActiveNotification")
    public static let willResignActiveNotification = Notification.Name("UIApplicationWillResignActiveNotification")
    public static let willEnterForegroundNotification = Notification.Name("UIApplicationWillEnterForegroundNotification")
    public static let didEnterBackgroundNotification = Notification.Name("UIApplicationDidEnterBackgroundNotification")
    public static let willTerminateNotification = Notification.Name("UIApplicationWillTerminateNotification")
    public static let didReceiveMemoryWarningNotification = Notification.Name("UIApplicationDidReceiveMemoryWarningNotification")
    public static let significantTimeChangeNotification = Notification.Name("UIApplicationSignificantTimeChangeNotification")
    public static let userDidTakeScreenshotNotification = Notification.Name("UIApplicationUserDidTakeScreenshotNotification")
    public static let didChangeStatusBarFrameNotification = Notification.Name("UIApplicationDidChangeStatusBarFrameNotification")
    public static let willChangeStatusBarFrameNotification = Notification.Name("UIApplicationWillChangeStatusBarFrameNotification")
    public static let protectedDataDidBecomeAvailableNotification = Notification.Name("UIApplicationProtectedDataDidBecomeAvailable")
    public static let protectedDataWillBecomeUnavailableNotification = Notification.Name("UIApplicationProtectedDataWillBecomeUnavailable")
    public static let openSettingsURLString = "app-settings:"
}
public struct UIBackgroundTaskIdentifier: RawRepresentable, Hashable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }
    public static let invalid = UIBackgroundTaskIdentifier(rawValue: 0) }

open class UIScene: UIResponder {
    public enum ActivationState: Int { case unattached = -1, foregroundActive = 0, foregroundInactive, background }
    public var activationState: ActivationState { .foregroundActive }
    public var title: String?
    public static let willConnectNotification = Notification.Name("UISceneWillConnectNotification")
    public static let didDisconnectNotification = Notification.Name("UISceneDidDisconnectNotification")
    public static let didActivateNotification = Notification.Name("UISceneDidActivateNotification")
    public static let willDeactivateNotification = Notification.Name("UISceneWillDeactivateNotification")
    public static let willEnterForegroundNotification = Notification.Name("UISceneWillEnterForegroundNotification")
    public static let didEnterBackgroundNotification = Notification.Name("UISceneDidEnterBackgroundNotification")
}
open class UIStatusBarManager: NSObject {
    public var statusBarFrame: CGRect { UIApplication.shared.statusBarFrame }
    public var isStatusBarHidden: Bool { false }
    public var statusBarStyle: UIStatusBarStyle { .default }
}
open class UIWindowScene: UIScene {
    nonisolated(unsafe) static let web = UIWindowScene()
    public var screen: UIScreen { .main }
    public var windows: [UIWindow] { UIApplication.shared.windows }
    public var keyWindow: UIWindow? { UIApplication.shared.keyWindow }
    public var interfaceOrientation: UIInterfaceOrientation { .portrait }
    public var traitCollection: UITraitCollection { UITraitCollection.current }
    public var statusBarManager: UIStatusBarManager? { UIStatusBarManager() }
    public var coordinateSpace: UICoordinateSpace { screen.coordinateSpace }
    public var isFullScreen: Bool { true }
    open class GeometryPreferences: NSObject {
        open class iOS: GeometryPreferences {
            public var interfaceOrientations: UIInterfaceOrientationMask
            public init(interfaceOrientations: UIInterfaceOrientationMask) { self.interfaceOrientations = interfaceOrientations }
        }
    }
    public func requestGeometryUpdate(_ p: GeometryPreferences, errorHandler: ((Error) -> Void)? = nil) {}
    public var effectiveGeometry: AnyObject? { nil }
}
