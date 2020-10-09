//
//  SeekableLiveStreamStatus.swift
//  ZDF
//
//  Created by Kai Huppmann on 12.05.20.
//  Copyright © 2020 CELLULAR GmbH. All rights reserved.
//
import os
import AVKit

/**
 This classes aim is to smoothen the progress reports of a seekable live stream to view and tracking delegates.
 The initial situation is, that the observing of seekable live streams,  which are played in the `AVPLayer` with
 the common approach to `addPeriodicTimeObserver` and checking `AVItem`'s
 `seekableTimeRanges` (`start` and `duration`), and use this results un-processed  leads
 to irregular results and inconsistent playhead / progress reportings. The exact shaping of the effect depends on
 variable properties of the stream, like chunksize and size of the seekable range.

 To get independent of different streams and situations, this class  models a status, which is more stable.
 The idea is, to init or reset a`SeekableLiveStreamStatus` object whenever a new live stream is
 started and then update this object with a periodic time observer.
 */


class SeekableLiveStreamStatus {

    // MARK: State

    /// The size of the time range, the user can seek
    private var livestreamSeekableDuration: CMTime = CMTime()

    /// The moment in in time the user started watching the stream
    private var livestreamStart: Date?

    /// The duration the user is watching
    private var secondsWatched: TimeInterval = 0

    /// The amount of time the user scrubbed to the past
    private var secondsScrubbed: TimeInterval = 0

    private var currentStreamDate: Date?

    /// The kind of seekable live stream this status reresents
    /// `true` if the seekable range moves through time and (nearly) keeps its size
    /// `false` if the  seekable range's start remains at a certain point and its duration is growing
    private var movingRange = true

    // MARK: lifecycle

    ///Resets this status. Call, when u wnat to re-use this one for a new live stream.
    public func reset() {
        livestreamSeekableDuration = CMTime()
        livestreamStart = nil
        secondsWatched = 0
        secondsScrubbed = 0
        movingRange = true
    }

    /**
     Calculates and stores all status details.
     - parameter currentItem: The `AVItem` currently played
     - parameter currentTime: The current time as the player reports it
     */
    public func update(for currentItem: AVPlayerItem, and currentTime: CMTime) {
        if let seekableRange = currentItem.seekableTimeRanges.last as? CMTimeRange {
            os_log(" --- SEEKABLE")
            os_log(" --- SEEKABLE current time as player says %{public}f", CMTimeGetSeconds(currentTime))
            if let currentDate = currentItem.currentDate() {
                currentStreamDate = currentDate
                os_log(" --- SEEKABLE current date as player says %{public}@", currentDate as NSDate)
            }
            let start = CMTimeGetSeconds(seekableRange.start)
            let duration = CMTimeGetSeconds(seekableRange.duration)

            os_log(" --- SEEKABLE current range as player says... Start: %{public}f, Dauer: %{public}f", start, duration )
            movingRange = seekableRange.start.seconds > 0.9 // if the start is bigger than zero it will keep growing and by that
                                                            // the original seekable time range keeps duration and moves
            os_log(" --- SEEKABLE it's a %{public}@ range", movingRange ? "moving" : "growing")
            if livestreamStart == nil {
                livestreamStart = Date()
                livestreamSeekableDuration = seekableRange.duration
            }
            if let start = livestreamStart {
                if livestreamSeekableDuration.seconds < seekableRange.duration.seconds {
                   livestreamSeekableDuration = seekableRange.duration
                } else if !movingRange {//it can be observed, that in case of live events (growing Time Ranges)
                                        //the duration is not constantly growing, but in leaps of several seconds.
                                        //since we need it constantly, especially for playhead tracking, we have to smoothen it.
                    let secondsSinceLastUpdate = Date().timeIntervalSince(start) - secondsWatched
                    livestreamSeekableDuration = CMTime(seconds: livestreamSeekableDuration.seconds + secondsSinceLastUpdate,
                                                        preferredTimescale: livestreamSeekableDuration.timescale)
                }
                secondsWatched = Date().timeIntervalSince(start)
                let durationCorrection = movingRange ? secondsWatched : 0.0
                secondsScrubbed = livestreamSeekableDuration.seconds + durationCorrection - currentTime.seconds
                if let livestreamStart = livestreamStart {
                    os_log(" --- SEEKABLE user started livestream watching: %{public}@", livestreamStart as NSDate)
                }
                os_log(" --- SEEKABLE calculated livestream seekable duration: %{public}f", CMTimeGetSeconds(livestreamSeekableDuration))
                os_log(" --- SEEKABLE calculated seconds watched:  %{public}f", secondsWatched)
                os_log(" --- SEEKABLE calculated seconds scrubbed:  %{public}f", secondsScrubbed)

                os_log(" --- SEEKABLE current diff %{public}f", diffLocalAndStreamTime)
                os_log(" --- SEEKABLE so now on server is: %{public}@", streamNowDate as NSDate)

                if let cRange = cleanSeekableRange() {
                     let cStart = CMTimeGetSeconds(cRange.start)
                     let cDuration = CMTimeGetSeconds(cRange.duration)
                     os_log(" --- SEEKABLE calculated range (cleanSeekableRange()) Start: %{public}f, Dauer: %{public}f", cStart, cDuration)
               }
            }
        }
    }


    // MARK: Calculated Seekable Live Stream properties

    /**
     - returns: The difference between the current time as reported by the local device
     and the time, the current stream's live playhead is supposed to be broadcasted.
     Normally the value is about 5 - 10 seconds, due to the latency which the live stream is
     sent and processed with.
     */
    public var diffLocalAndStreamTime: TimeInterval {
        guard let currentStreamDate = currentStreamDate else {
            return 0
        }
        return Date().timeIntervalSince1970 - currentStreamDate.timeIntervalSince1970 - secondsScrubbed
    }

    /**
     - returns: The current date (now) with respect to the stream.
     Normally the value is about 5 - 10 seconds behind the real time, \
     due to the latency which the live stream is sent and processed with.

     # Example #

     A sports event, which started exactly at 5 pm in the 'real world' and
     ran for 39 minutes and 12 seconds is viewed on an iPhone. While
     `Date()` will return `Tue Aug 18 17:39:12 2020` ,
     `streamNowDate` will be `Tue Aug 18 17:39:04 2020`,
     because of the streams latency.
     In a nutshell: The iPhone's user looks at what happened 8 seconds
     ago and this property knows.
     */
    public var streamNowDate: Date {
        guard let currentStreamDate = currentStreamDate else {
            return Date()
        }
        return Date(timeInterval: secondsScrubbed, since: currentStreamDate)
    }

    // MARK: Smoothed Seekable Live Stream Properties

    /**
     - returns: A smoothed `CMTimeRange` representing the seekable range of the
     live stream this status represents. Bears nearly the same vale as the original time rane the
     `AVItem` reports, but without the confusing jumps in `start` and `duration`
     */
    public func cleanSeekableRange() -> CMTimeRange? {
        let start = movingRange ?
            //If the range is moving, the start will be at seconds watched by the user (moves forward)
            CMTime(seconds: secondsWatched, preferredTimescale: livestreamSeekableDuration.timescale) :
            //If the range is not moving the start will be at 0.0 forever
            CMTime(seconds: 0.0, preferredTimescale: livestreamSeekableDuration.timescale)
        return CMTimeRange(start: start, duration: livestreamSeekableDuration)
    }

    /**
     - returns: A smooth, continouus playhead position without the jumps created by incontinoous
     reports from `AVPLayer`
     */
    public func playheadPosition() -> TimeInterval {
        return Date().timeIntervalSince1970 - secondsScrubbed
    }

    /**
     - returns: The current position of this status in a seekable live stream, where `0` means "scrubbed all the way back"
     and on the other hand, when the user didn't scrub at all the position will be the duration of the seekable range.
`     */
    public func currentPosition() -> CMTime? {
        if let range = cleanSeekableRange() {
            let currentPositionSeconds = range.duration.seconds - secondsScrubbed
            return CMTime(seconds: currentPositionSeconds, preferredTimescale: range.start.timescale)
        }
        return nil
    }
}
