//
//  MediaPlaybackProgress.swift
//  ZDF
//
//  Created by Jonas Wippermann on 15.10.18.
//  Copyright © 2018 CELLULAR GmbH. All rights reserved.
//

import Foundation
import CoreMedia

/// Encapsulates player progress updates with the current playback context
enum MediaPlaybackProgress {

	/// non-live, on demand
	/// position: progres in seconds
	/// duration: duration of asset in seconds
	/// loadedRange: the loaded range (~ "buffer")
	case vod(position: Double, duration: Double, loadedRange: CMTimeRange?)

	/// live asset, no progress to be tracked
	case live

	/// 'DVR'-Live, is live but can be seeked
	/// range: range the user can seek to
	/// current: the current time (where the playhead is) - NOTE: this includes the start of the range,
	///     so if the range.start is 5 sec and the user is 3 sec ahead of the start, the currentTime is 8 sec
	///     This needs to be considered when calculating the current progress
	case seekableLive(range: CMTimeRange, currentTime: CMTime, currentDate: Date?)
}

/// Represents playback in context of the seekable range of a playing stream.
/// Please see `PassedLiveEventProgress` for more context
typealias SeekableRangeProgress = Double

/// Represents playback in context of the seekable range of an ongoing live event
/// In case a live event is happening, we have a live stream with a seekableRange,
/// but we also have information about the live event (see `Highlights.LiveStreamInfo`), such as the start and end of the event.
/// The requirement is for us to only show the "live event range" of the stream to the user, while the player still has the entire
/// seekable range.
/// Thus, we have two kinds of "progresses". One is the progress the user sees, which is a `PassedLiveEventProgress`, which we internally
/// convert to a `SeekableRangeProgress` when executing a seek or updating the player based on its current progress.
typealias PassedLiveEventProgress = Double

extension SeekableRangeProgress {

	/// Converts a `SeekableRangeProgress` to a `PassedLiveEventProgress`.
	/// Please see `PassedLiveEventProgress` for an explanation as to why we need thi
	///
	/// - Parameters:
	///   - seekableRangeDuration: The seekable range of the asset playing in the player
	///   - passedLiveEventDuration: The range of the ongoing live event, which has passed (so from the start of it, up to now (the current
	///   point in time))
	///   - prerollDuration: duration of 'preroll' to consider, so time of seekableRange before event started
	func convertToLiveEventProgress(seekableRangeDuration: Double, passedLiveEventDuration: Double, prerollDuration: TimeInterval)
		-> PassedLiveEventProgress {
		return ((self * seekableRangeDuration) - prerollDuration) / passedLiveEventDuration
	}
}

extension PassedLiveEventProgress {

	/// Converts a `PassedLiveEventProgress` to a `SeekableRangeProgress`.
	/// Please see `PassedLiveEventProgress` for an explanation as to why we need thi
	///
	/// - Parameters:
	///   - seekableRangeDuration: The seekable range of the asset playing in the player
	///   - passedLiveEventDuration: The range of the ongoing live event, which has passed (so from the start of it, up to now (the current
	///   point in time))
	///   - prerollDuration: duration of 'preroll' to consider, so time of seekableRange before event started
	func convertToSeekableRangeProgress(seekableRangeDuration: Double, passedLiveEventDuration: Double, prerollDuration: TimeInterval)
		-> SeekableRangeProgress {

		return ((self * passedLiveEventDuration) + prerollDuration) / seekableRangeDuration
	}
}
