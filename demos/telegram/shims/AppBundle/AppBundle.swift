// Swiftboard web port: Swift stand-in for Telegram's AppBundle (ObjC module). Images resolve through UIKit's WebAssets.
import Foundation
import UIKit

public func getAppBundle() -> Bundle { Bundle.main }

extension UIImage {
    public convenience init?(bundleImageName: String) { self.init(named: bundleImageName) }
}
