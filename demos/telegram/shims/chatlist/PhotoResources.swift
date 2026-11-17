// Swiftboard web port: PhotoResources (decodes photo/video thumbnails from MediaBox through ImageIO/mozjpeg). The web
// port has no media store yet: these signals complete without an image, so media previews stay empty.
import Foundation
import UIKit
import SwiftSignalKit
import Display
import Postbox
import TelegramCore
public func chatSecretPhoto(account: Account, userLocation: MediaResourceUserLocation, photoReference: ImageMediaReference, ignoreFullSize: Bool = false, synchronousLoad: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> { .complete() }
public func mediaGridMessagePhoto(account: Account, userLocation: MediaResourceUserLocation, photoReference: ImageMediaReference, fullRepresentationSize: CGSize = CGSize(width: 127.0, height: 127.0), blurred: Bool = false, synchronousLoad: Bool = false, automaticFetch: Bool = true) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> { .complete() }
public func mediaGridMessageVideo(postbox: Postbox, userLocation: MediaResourceUserLocation, userContentType customUserContentType: MediaResourceUserContentType? = nil, videoReference: FileMediaReference, hlsFiles: [(playlist: TelegramMediaFile, video: TelegramMediaFile)] = [], onlyFullSize: Bool = false, useLargeThumbnail: Bool = false, synchronousLoad: Bool = false, autoFetchFullSizeThumbnail: Bool = false, overlayColor: UIColor? = nil, nilForEmptyResult: Bool = false, useMiniThumbnailIfAvailable: Bool = false, blurred: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> { .complete() }
