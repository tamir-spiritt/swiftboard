// Swiftboard web port: stand-in for Telegram module Postbox (API surface the chat list uses, fake data).
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

// MARK: identifiers and media (shapes of Postbox's types; no storage)
public typealias PeerId = EnginePeerId
public struct EnginePeerId: Hashable, Comparable, CustomStringConvertible {
    public struct Namespace: Hashable, Comparable {
        public let rawValue: Int32
        public init(_ v: Int32) { rawValue = v }
        public static func _internalFromInt32Value(_ v: Int32) -> Namespace { Namespace(v) }
        public static func < (a: Namespace, b: Namespace) -> Bool { a.rawValue < b.rawValue }
    }
    public struct Id: Hashable, Comparable {
        public let rawValue: Int64
        public static func _internalFromInt64Value(_ v: Int64) -> Id { Id(rawValue: v) }
        public func _internalGetInt64Value() -> Int64 { rawValue }
        public static func < (a: Id, b: Id) -> Bool { a.rawValue < b.rawValue }
    }
    public let namespace: Namespace
    public let id: Id
    public init(namespace: Namespace, id: Id) { self.namespace = namespace; self.id = id }
    public init(_ v: Int64) { namespace = Namespace(0); id = Id(rawValue: v) }
    public func toInt64() -> Int64 { id.rawValue }
    public static func < (a: EnginePeerId, b: EnginePeerId) -> Bool { (a.namespace, a.id) < (b.namespace, b.id) }
    public var description: String { "\(namespace.rawValue):\(id.rawValue)" }
}
public struct MediaId: Hashable, Comparable {
    public typealias Namespace = Int32
    public typealias Id = Int64
    public let namespace: Int32
    public let id: Int64
    public init(namespace: Int32, id: Int64) { self.namespace = namespace; self.id = id }
    public static func < (a: MediaId, b: MediaId) -> Bool { (a.namespace, a.id) < (b.namespace, b.id) }
}
public struct MessageId: Hashable, Comparable {
    public typealias Namespace = Int32
    public typealias Id = Int32
    public let peerId: PeerId
    public let namespace: Int32
    public let id: Int32
    public init(peerId: PeerId, namespace: Int32, id: Int32) { self.peerId = peerId; self.namespace = namespace; self.id = id }
    public static func < (a: MessageId, b: MessageId) -> Bool { (a.namespace, a.id) < (b.namespace, b.id) }
}
public struct MessageIndex: Hashable, Comparable {
    public let id: MessageId
    public let timestamp: Int32
    public init(id: MessageId, timestamp: Int32) { self.id = id; self.timestamp = timestamp }
    public static func < (a: MessageIndex, b: MessageIndex) -> Bool { (a.timestamp, a.id) < (b.timestamp, b.id) }
}
public protocol MediaResourceId { var stringRepresentation: String { get } }
public struct MediaResourceIdString: Hashable { public let stringRepresentation: String; public init(_ s: String) { stringRepresentation = s } }
public protocol MediaResource: AnyObject {
    var id: MediaResourceIdString { get }
    var size: Int64? { get }
}
public final class EmptyMediaResource: MediaResource {
    public init() {}
    public var id: MediaResourceIdString { MediaResourceIdString("empty") }
    public var size: Int64? { nil }
}
public protocol Media: AnyObject { var id: MediaId? { get } }
public struct PixelDimensions: Hashable {
    public let width: Int32, height: Int32
    public init(width: Int32, height: Int32) { self.width = width; self.height = height }
    public init(_ size: CGSize) { width = Int32(size.width); height = Int32(size.height) }
    public var cgSize: CGSize { CGSize(width: CGFloat(width), height: CGFloat(height)) }
}
