//
//  AVPlayerItem+Current.swift
//  ZDF
//
//  Created by Jonas Wippermann on 06.08.20.
//  Copyright © 2020 CELLULAR GmbH. All rights reserved.
//

import Foundation
import AVKit

public extension AVPlayerItem {

    /// fraction of current time and current item duration, so value between 0 and 1
    /// nil if item does not have a duration
    var currentProgress: Double? {
        let currentTime = self.currentTime()
        let duration = asset.duration
        guard currentTime.canBeUsed, duration.canBeUsed else { return nil }
        let progress: Double = currentTime.seconds / duration.seconds
        guard progress.canBeUsed else { return nil }
        return progress
    }

     /// a valid time range the player can seek to, the last one if multiple ranges are available
    var lastSeekableRange: CMTimeRange? {
        return seekableTimeRanges.compactMap({ $0 as? CMTimeRange }).last(where: {
            $0.start.flags.contains(.valid) && $0.duration.flags.contains(.valid)
        })
    }

    /// progress in relation to the (last) seekable range available
    var currentProgressInLastSeekableRange: Double? {
        guard let range = lastSeekableRange else { return nil }
        let currentTime = self.currentTime()
        let duration = range.duration
        guard currentTime.canBeUsed, duration.canBeUsed else { return nil }
        let progress: Double = (currentTime.seconds - range.start.seconds) / duration.seconds
        guard progress.canBeUsed else { return nil }
        return progress
    }

    /// the time range loaded by the player
    var loadedRange: CMTimeRange? {
        /// heuristic: normally only one time range is loaded, so use `first`
        return loadedTimeRanges.compactMap({ $0 as? CMTimeRange })
            .first(where: { $0.start.flags.contains(.valid) && $0.duration.flags.contains(.valid) })
    }
}
