// Swiftboard web port: stand-in for Telegram module ItemListUI (API surface the chat list uses, fake data).
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

/// Upstream ItemListControllerNode.swift (the settings-list controller, not built).
public typealias ItemListSectionId = Int32

/// Upstream Items/ItemListTextItem.swift (a settings-list text cell, not built). ItemListNeighborFacet only tests
/// `is ItemListTextItem`; the web port never creates one.
public final class ItemListTextItem {}
