//
//  MediaAsset.swift
//  ZDF
//
//  Created by Helge Carstensen on 03.07.17.
//  Copyright © 2017 CELLULAR GmbH. All rights reserved.
//

import Foundation

/// This is a protocol, so we can keep MediaPlayerController a general-purpose-player,
/// but inspect application-specific properties on the currently playing asset
/// The player only needs url, mimetype and identifier to work, the properties specified in this protocol
/// An app might want or need additional properties (e.g. if several variants of a stream are playable, as done
/// in ZDF's VideoTeaserMediaAsset)
/// The protocol avoids making the MediaPlayerController too specific and keeps implementation details separate
protocol MediaAsset {
    var url: URL { get }
    var mimeType: String? { get }

    // identifier is used to distinguish if asset is already playing
    var identifier: String { get }
}
