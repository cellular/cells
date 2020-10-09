//
//  MediaPlayerControllerDelegate.swift
//  ZDF
//
//  Created by Helge Carstensen on 03.07.17.
//  Copyright © 2017 CELLULAR GmbH. All rights reserved.
//

import Foundation
import AVKit

protocol MediaPlayerControllerDelegate: class {

    func playerDidChangeState<Asset: MediaAsset>(_ controller: MediaPlayerController<Asset>, state: MediaPlayerState)
    func playerDidChangePlaybackProgress<Asset: MediaAsset>(_ controller: MediaPlayerController<Asset>, progress: MediaPlaybackProgress)
    func playerDidChangeExternalPlayback<Asset: MediaAsset>(_ controller: MediaPlayerController<Asset>, externalPlaybackActive: Bool)
    func playerDidPreparePlaybackForItem<Asset: MediaAsset>(_ controller: MediaPlayerController<Asset>, item: AVPlayerItem)
    func playerItemTimeDidJump<Asset: MediaAsset>(_ controller: MediaPlayerController<Asset>, currentTime: Double?)
    func playerItemDidFinishPlaying<Asset: MediaAsset>(_ controller: MediaPlayerController<Asset>, asset: Asset?)
    func playerDidTriggerTrackingEvent<Asset: MediaAsset>(_ controller: MediaPlayerController<Asset>, event: MediaPlayerTrackingEvent)
}

// Low-level events needed for MediaPlayerTrackingDelegate
enum MediaPlayerTrackingEvent {
    case readyToPlay
    case play
    case pause
    case didReachEnd
    case stop
    case playbackActive
    case playhead(position: Int64)
    case startSeekTo
    case endSeekTo
}
