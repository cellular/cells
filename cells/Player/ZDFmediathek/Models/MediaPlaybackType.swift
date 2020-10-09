//
//  MediaPlaybackType.swift
//  ZDF
//
//  Created by Jonas Wippermann on 18.10.18.
//  Copyright © 2018 CELLULAR GmbH. All rights reserved.
//

import Foundation
import AVKit

/// Represents the type of media played in respect to its duration (continuous, finite, DVR?)
/// This type is intended to be inferred from the item's properties (see AVPlayerItem extension)
enum MediaPlaybackType {
    /// "video on demand", a non-live video with deterministic duration
    case vod

    /// a live stream, which allows seeking back, also called "DVR" stream
    case seekableLive

    /// a regular live stream, not seekable, no known duration
    case live
}

extension AVPlayerItem {
    var playbackType: MediaPlaybackType {
        if duration.isValid, !CMTIME_IS_INDEFINITE(duration) {
            return .vod
        }

        if let seekableRange = seekableTimeRanges.first as? CMTimeRange, seekableRange.duration.seconds > 30 {
            return .seekableLive
        }

        return .live
    }
}
