// Swiftboard web port: shim for the rest of TelegramPresentationData.
import Foundation
import UIKit
import Display
import TelegramCore

/// Upstream DefaultPresentationStrings.swift reads Localizable.strings from the app bundle (`Bundle.main`, which traps
/// on WASI: there is no executable path). The web build compiles the same English strings into PresentationStrings
/// (tools/gen-strings.py), so the default strings need no file. assemble.py drops the upstream declaration.
public let defaultPresentationStrings = PresentationStrings()
