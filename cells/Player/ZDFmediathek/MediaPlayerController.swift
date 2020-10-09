//
//  MediaPlayerController.swift
//  ZDF
//
//  Created by Helge Carstensen on 03.07.17.
//  Copyright © 2017 CELLULAR GmbH. All rights reserved.
//
//  MEDIA PLAYER
//  An introductory document to the media player implementation can be found in confluence as "Player Implementierung"
//  and can (currently) be found here: https://confluence.cellular.de/display/zdfapp/Player+Implementierung

import Foundation
import AVKit

// swiftlint:disable:next type_body_length
final class MediaPlayerController<Asset: MediaAsset>: NSObject {

	// MARK: - Private enumerations
	private enum PreparedState {
		case notPrepared
		case preparing
		case prepared
	}

	// MARK: - Public properties

	weak var delegate: MediaPlayerControllerDelegate?

	private(set) var asset: Asset?

	var state: MediaPlayerState = .idle {
		didSet {
			if oldValue != state {
				delegate?.playerDidChangeState(self, state: state)
			}
		}
	}

	var currentItem: AVPlayerItem? {
		return player.currentItem
	}

	/// fraction of current time and current item duration, so value between 0 and 1
	/// nil if current item does not have a duration
	var currentProgress: Double? {
		return currentItem?.currentProgress
	}

	var currentTime: CMTime? {
		guard let currentTime = player.currentItem?.currentTime(), currentTime.canBeUsed else { return nil }
		return currentTime
	}

	var currentDate: Date? {
		return currentItem?.currentDate()
	}

	var currentTimeInSeconds: Double? {
		return currentTime?.seconds
	}

	var assetDuration: Double? {
		guard let duration = currentItem?.asset.duration, duration.canBeUsed else { return nil }
		return duration.seconds
	}

	/// the time range the player can seek to
	var seekableRange: CMTimeRange? {
		return currentItem?.lastSeekableRange
	}

	/// progress in relation to the seekable range for the current item
	/// This property only makes sense in the `seekableLive`-context
	var currentSeekableRangeProgress: Double? {
		return currentItem?.currentProgressInLastSeekableRange
	}

	/// the time range loaded by the player
	var loadedRange: CMTimeRange? {
		return currentItem?.loadedRange
	}

	var volume: Float {
		get { return player.volume }
		set { player.volume = newValue }
	}

	var muted: Bool {
		get { return player.isMuted }
		set { player.isMuted = newValue }
	}

	var playbackType: MediaPlaybackType? {
		return currentItem?.playbackType
	}

	var isPictureInPictureActive: Bool {
		guard let pictureInPictureController = pictureInPictureController else { return false }
		return pictureInPictureController.isPictureInPictureActive
	}

	var isAirplayActive: Bool {
		return player.isExternalPlaybackActive
	}

	var isAirplayAllowed: Bool {
		get { return player.allowsExternalPlayback }
		set { player.allowsExternalPlayback = newValue }
	}

	var currentURL: URL? {
		return ((currentItem?.asset) as? AVURLAsset)?.url
	}

	// MARK: - Public properties

	internal let player: AVPlayer = AVPlayer()

	// MARK: - Private properties
	private let configuration: Configuration
	
	private var preparedState: PreparedState = .notPrepared
	private var pictureInPictureController: AVPictureInPictureController?
	private var isObserving: Bool = false // make sure we don't accidently add/remove twice, otherwise we crash
	private var isObservingItem: Bool = false
	private var isBufferEmpty: Bool = true
	private var playRequestQueue = OperationQueue() // hold play (and prepareToPlay) requests in a queue, so they can be canceled
	private let observerQueue: DispatchQueue // synchronize access to isObserving flag
	private var didReachEnd = false
	private var isPausedByEmptyBuffer = false

	/// A status, knowing all about playhead, back-scroll etc. of a played seekable live stream
	/// For details check out the implementation at`SeekableLiveStreamStatus`
	private let seekableLiveStreamStatus = SeekableLiveStreamStatus()

	/// Used for 'play' or 'seek' requests when player is not ready yet
	private var pendingReadyToPlayTasks: [() -> Void] = []

	/// When we switch stream variants, we need to resume at the same position, which we do by storing and seeking.
	/// With seekable-livestreams, we can't seek immediately, because the player needs some time to fetch a `seekableRange`
	/// Thus, we sometimes need to store the desired seek value in this property and use it later, once we are able to seek
	private var pendingSeekRequestValue: (position: Double, completion: ((Bool) -> Void)?)?

	/// Hold off pending PiP requests when player is not ready yet
	private var pictureInPictureRequestIsPending: Bool = false

	// Player Observers
	private var timeObserver: Any?
	private var playbackActiveObserver: Timer?

	// MARK: - Initialization

	///   - defaults: The audio/subtitle defaults which should be enabled after player item has loaded
	init(with asset: Asset? = nil, configuration: Configuration, defaults: MediaAssetDefaults = .none) {
		observerQueue = DispatchQueue(label: "de.zdf.mediathek.playerObserver", qos: .userInteractive)
		self.configuration = configuration
		super.init()

		do {
			try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
		} catch { }

		do {
			try AVAudioSession.sharedInstance().setActive(true)
		} catch { }

		setAsset(asset, defaults: defaults)
	}

	deinit {
		stopObserving()
	}

	// MARK: - Public functions

	/// Sets asset on player controller.
	/// NOTE: Setting the asset on the AVPlayer instance starts buffering and loading the video
	///   - defaults: The audio/subtitle defaults which should be enabled after player item has loaded
	func setAsset(_ asset: Asset?, defaults: MediaAssetDefaults = .none) {
		// Don't prepare again, if we already set this asset on the player
		if asset != nil, self.asset?.identifier == asset?.identifier && preparedState == .prepared {
			return
		}

		// set new asset
		self.asset = asset

		// if new asset is nil, reset player
		if asset == nil {
			stopObserving()
			resetPlayerState()
			stopItemObservingIfNotNil(item: player.currentItem)
			DispatchQueue.main.async { [weak self] in
				self?.player.replaceCurrentItem(with: nil)
			}
			return
		}

		preparedState = .notPrepared
		prepareForPlayback { [weak self] in // player is ready, select predefined options if desired
			if defaults.showSubtitles {
				if let subtitles = self?.currentItem?.probablySubtitleOption {
					self?.select(option: subtitles.0, in: subtitles.1)
				}
			}

			if defaults.useAudioDescription {
				if let audioDescription = self?.currentItem?.probablyAudioDescriptionOption {
					self?.select(option: audioDescription.0, in: audioDescription.1)
				}
			}
		}
	}

	/// Takes the view's layer and sets its player property to the controller's AVPlayer
	/// NOTE: The passed UIView needs to overwrite its layerClass property to return an AVPlayerLayer
	func attach(view: UIView) {

		// Don't re-attach if player is already attached
		if let existingPlayer = (view.layer as? AVPlayerLayer)?.player, existingPlayer == player {
			return
		}

		(view.layer as? AVPlayerLayer)?.player = player
	}

	/// Operation to be called in prepareForPlayback, then gets added to the operation queue
	private func prepareForPlaybackOperation(completion: (() -> Void)?) {
		// Add completion task as pending readytoplayTasks
		if let completion = completion {
			pendingReadyToPlayTasks.append(completion)
		}

		// Player is already prepared, and thus won't switch to readyToPlay again, which would trigger `executePendingTasks..`
		// Thus, triger it here
		if preparedState == .prepared {
			executePendingReadyToPlayTask()
			return // Nothing else to do, player is already prepared
		}

		guard preparedState == .notPrepared else { return } // player is already preparing/prepared
		guard let asset = self.asset else { return } // don't prepare for play without an asset
		preparedState = .preparing

		startObserving()

		var options: [String : Any]?
		if let customUserAgent = configuration.customUserAgent {
			let userAgentHeader: [String: String] = ["User-Agent": customUserAgent]
			options = ["AVURLAssetHTTPHeaderFieldsKey": userAgentHeader]
		}
		
		let avAsset = AVURLAsset(url: asset.url, options: options)
		// Don't set asset until it has a duration
		avAsset.loadValuesAsynchronously(forKeys: ["duration"], completionHandler: {
			DispatchQueue.main.async { [weak self] in
				guard let this = self else { return }
				let playerItem = AVPlayerItem(asset: avAsset)

				// Only set if item is not already set, prevent re-start
				if asset.url != (this.player.currentItem?.asset as? AVURLAsset)?.url {
					this.stopItemObservingIfNotNil(item: this.player.currentItem)
					this.player.replaceCurrentItem(with: playerItem)
				}
				this.startItemObservingIfNotNil(item: this.player.currentItem)
				this.preparedState = .prepared
				this.delegate?.playerDidPreparePlaybackForItem(this, item: playerItem)
				this.executePendingReadyToPlayTask() // When duration is loaded, player is readyToPlay
			}
		})
	}

	/// Ensures that the MediaPlayerController is configured with the current asset and is observing all relevant rate/status changes
	/// of the underlying AVPlayer. If a valid completion closure is provided, it will be executed when the player is readytoplay completed.
	private func prepareForPlayback(completion: (() -> Void)? = nil) {
		playRequestQueue.addOperation { [weak self] in
			self?.prepareForPlaybackOperation(completion: completion)
		}
	}

	func cancelOngoingPlayRequest() {
		pendingReadyToPlayTasks = [] // Reset pending tasks
		playRequestQueue.cancelAllOperations()
	}

	// MARK: - Core Playback functions

	func play() {
		// check for valid asset
		guard asset != nil else { return }
		guard player.rate != 1.0 else { return } // Only trigger play action if not already playing, avoid duplicate tracking

		if preparedState == .prepared {
			player.play()
		} else {
			prepareForPlayback(completion: { [weak self] in
				self?.player.play()
			})
		}
	}

	func pause() {
		stopPlaybackActiveObserving()
		player.pause()
	}

	func stop() {
		stopItemObservingIfNotNil(item: player.currentItem)
		stopObserving()
		resetPlayerState()
		player.replaceCurrentItem(with: nil)
		preparedState = .notPrepared
		if !didReachEnd {
			delegate?.playerDidTriggerTrackingEvent(self, event: .stop)
		}
	}

	/// Selects the specified AVMediaSelectionOption in the specified AVMediaSelectionGroup.
	/// This is used to select a different audio track or to activate subtitles in the media player.
	/// In our case the AVMediaSelectionGroup can be 'audible' (audio track) or 'legibile' (subtitles).
	func select(option: AVMediaSelectionOption?, in group: AVMediaSelectionGroup) {
		player.currentItem?.select(option, in: group)
	}

	func seekTo(position: Double, completion: ((Bool) -> Void)? = nil) {
		let position = position > 1 ? 1 : position < 0 ? 0 : position // safety check: progress should be between 0 and 1

		// if player is not prepared, call the prepare function with the completion closure provided and stop seekTo execution
		if preparedState != .prepared {
			prepareForPlayback(completion: { [weak self] in
				self?.seekTo(position: position, completion: completion)
			})
			return
		}

		// preparedState is now 'prepared', so current item (asset) must have a duration, at least if it's not a live stream
		if let duration = player.currentItem?.asset.duration, !CMTIME_IS_INDEFINITE(duration), CMTIME_IS_VALID(duration) {
			var adjustedPosition = position

			// if the user drags the slider to the end, seek to shortly before the end,
			// so the video transitions smoothly to its 'finished' state.
			// This is more convenient than manually triggering the 'finished' actions from here
			if adjustedPosition >= 1 {
				adjustedPosition = 1.0 - (0.05 / (Double(duration.value) / Double(duration.timescale)))
			}

			let absoluteTime = CMTime(value: Int64(Double(duration.value) * adjustedPosition), timescale: duration.timescale)
			guard CMTIME_IS_VALID(absoluteTime) else {
				completion?(false)
				return
			}

			state = .seeking
			delegate?.playerDidTriggerTrackingEvent(self, event: .startSeekTo)
			// Without `toleranceBefore` and `toleranceAfter`, the seeks become inaccurate (sometimes off by a whole second), which
			// affects the HighlightsMode
			player.seek(to: absoluteTime, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { [weak self] finished in
				if let this = self {
					if (self?.player.currentItem?.asset as? AVURLAsset)?.url.absoluteString.contains("file://") == true {
						// ZDFMEDIATHEK-4527: Downloaded videos won't buffer after seeking, so they will stuck in .seeking
						// state. Because of this, we have to check, if asset is downloaded (url is file:// instead of http://
						// and rate is in playing condition to set the state to .playing / .paused manually.
						if (self?.player.rate ?? 0.0) > 0.0 {
							self?.state = .playing
						} else {
							self?.state = .paused
						}
					}
					this.resetPlaybackActiveObserver()
					this.delegate?.playerDidTriggerTrackingEvent(this, event: .endSeekTo)
				}
				completion?(finished)
			})
			// asset is not VOD and seekable ranges are available
		} else if let range = seekableRange {
			let newSeconds = range.start.seconds + (range.duration.seconds * position)
			let new = CMTime(seconds: newSeconds, preferredTimescale: player.currentTime().timescale)
			state = .seeking
			delegate?.playerDidTriggerTrackingEvent(self, event: .startSeekTo)
			player.seek(to: new, completionHandler: { [weak self] finished in
				if let this = self {
					this.resetPlaybackActiveObserver()
					this.delegate?.playerDidTriggerTrackingEvent(this, event: .endSeekTo)
				}
				completion?(finished)
			})
		} else {
			// There was a request to seek, but no duration or seekable range is present.
			// This can happen after an 'alternative stream' switch, where the seekable range needs some time to load.
			// Store the seek request and fulfil it once possible
			pendingSeekRequestValue = (position, completion)
			completion?(false)
		}
	}

	public func resumeLiveStream() {
		guard playbackType == .live else { return }

		if preparedState == .notPrepared {
			prepareForPlayback(completion: { [weak self] in
				self?.resumeLiveStream()
			})
			return
		}

		if let livePosition = player.currentItem?.seekableTimeRanges.last as? CMTimeRange,
			CMTIME_IS_VALID(CMTimeRangeGetEnd(livePosition)) {
			state = .seeking
			player.seek(to: CMTimeRangeGetEnd(livePosition)) { [weak self] _ in
				self?.player.play()
			}
		} else { // no seekable ranges (yet), but let's still play
			player.play()
		}
	}

	// MARK: - Picture In Picture

	/// Creates an AVPictureInPictureController for the passed view based on the view's layer
	/// the AVPipController might not be needed until pip starts, but is required to support iOS's "auto-Pip" feature
	/// when leaving the app while fullscreen playback is active
	/// So when the player enters fullscreen, a "pip player view" is set and the matching avPipController is generated here
	/// This way, the os can activate PiP when needed
	/// NOTE: The passed UIView needs to overwrite its layerClass property to return an AVPlayerLayer
	func prepareForPictureInPicturePlayback(on playerView: UIView, delegate: AVPictureInPictureControllerDelegate? = nil) {

		DispatchQueue.main.async { [weak self] in
			guard let playerLayer = (playerView.layer as? AVPlayerLayer) else { return }
			guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
			// Only re-set if necessary
			if self?.pictureInPictureController == nil || self?.pictureInPictureController?.playerLayer != playerLayer {
				self?.pictureInPictureController = AVPictureInPictureController(playerLayer: playerLayer)
			}

			if let delegate = delegate, self?.pictureInPictureController?.delegate !== delegate {
				self?.pictureInPictureController?.delegate = delegate
			}
		}
	}

	/// Starts PiP playback, generates AVPiP controller if not already present
	func startPictureInPicture(on playerView: UIView, delegate: AVPictureInPictureControllerDelegate? = nil) {
		prepareForPictureInPicturePlayback(on: playerView, delegate: delegate)

		// Check if pip is currently possible, else - wait for it to become available
		DispatchQueue.main.async { [weak self] in
			guard let pipController = self?.pictureInPictureController else { return }
			if pipController.isPictureInPicturePossible {
				pipController.startPictureInPicture()
				self?.play()
			} else {
				self?.pictureInPictureRequestIsPending = true
				pipController.addObserver(self!, forKeyPath: #keyPath(AVPictureInPictureController.isPictureInPicturePossible),
										  options: .new, context: nil)
			}
		}
	}

	func stopPictureInPicture() {
		// Calling pictureInPictureController?.stopPictureInPicture() instead of setting to nil will trigger a restore, which is not desired
		DispatchQueue.main.async { [weak self] in
			self?.pictureInPictureController = nil
		}
	}

	// MARK: - Private functions

	private func resetPlayerState() {
		player.rate = 0
		state = .idle
		isBufferEmpty = true
	}

	private func updateMediaPlayerState() {

		// check for valid asset
		if asset == nil {

			state = .idle
			return
		}

		// check AVPlayer status; if it's not ready to play, mirror its state
		switch player.status {

		case .failed:
			state = .error

		case .unknown:
			state = .idle

		case .readyToPlay:
			switch player.rate {
			case 0.0: state = .paused
			case let rate where rate > 0.0: state = isBufferEmpty ? .buffering : .playing
			case let rate where rate < 0.0: state = isBufferEmpty ? .buffering : .reversed
			default: break
			}
		default: break
		}
	}

	private func executePendingReadyToPlayTask() {
		pendingReadyToPlayTasks.forEach { $0() }
		pendingReadyToPlayTasks = []
	}

	// MARK: - AVPlayer related KVO/Notification observing

	private func startObserving() {
		observerQueue.sync { [weak self] in
			guard let this = self else { return }
			guard !this.isObserving else { return }

			// register for changes in AVPlayer and AVPlayerItem changes
			this.player.addObserver(this, forKeyPath: #keyPath(AVPlayer.status), options: .new, context: nil)
			this.player.addObserver(this, forKeyPath: #keyPath(AVPlayer.rate), options: .new, context: nil)
			this.player.addObserver(this, forKeyPath: #keyPath(AVPlayer.currentItem.isPlaybackBufferEmpty), options: .new, context: nil)
			this.player.addObserver(this, forKeyPath: #keyPath(AVPlayer.currentItem.isPlaybackLikelyToKeepUp), options: .new, context: nil)
			this.player.addObserver(this, forKeyPath: #keyPath(AVPlayer.isExternalPlaybackActive), options: .new, context: nil)

			//reset the status, though it's only needed/working for seekable live streams
			seekableLiveStreamStatus.reset()

			// Periodic time observer
			let time: CMTime = CMTimeMakeWithSeconds(1.0, preferredTimescale: Int32(NSEC_PER_SEC))
			self?.timeObserver = this.player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] _ in
				guard let self = self else { return }
				guard let currentTime: CMTime = self.currentTime else { return }
				guard let currentItem = self.currentItem else { return }

				//update the status, though it's only needed/working for seekable live streams
				self.seekableLiveStreamStatus.update(for: currentItem, and: currentTime)

				//reporting the progress to the delegate (coordinator), mainly to update views
				self.reportProgress(for: currentItem, and: currentTime)

				//reporting the current playhead to tracking (especially needed for Nielsen)
				self.trackPlayhead(for: currentItem, and: currentTime)

				// if player progresses, we are now likely able to seek, so handle any stored seek request
				self.handlePendingLiveSeek()
			}
			self?.isObserving = true
		}
	}

	private func reportProgress(for currentItem: AVPlayerItem, and currentTime: CMTime) {
		var playheadPosition: Double = 0
		switch currentItem.playbackType {
		case .vod:
			playheadPosition = Double(currentTime.seconds)
			let progress: MediaPlaybackProgress = .vod(position: playheadPosition,
														duration: currentItem.duration.seconds,
														loadedRange: loadedRange)
			delegate?.playerDidChangePlaybackProgress(self, progress: progress)
		case .seekableLive:
			if let seekableRange = seekableLiveStreamStatus.cleanSeekableRange() {
				let progress: MediaPlaybackProgress = .seekableLive(range: seekableRange,
																	currentTime: currentTime,
																	currentDate: currentDate)
				delegate?.playerDidChangePlaybackProgress(self, progress: progress)
			}
		case .live:
			delegate?.playerDidChangePlaybackProgress(self, progress: .live)
		}
	}


	private func stopObserving() {
		stopPlaybackActiveObserving()
		observerQueue.sync {
			guard self.isObserving else { return }

			// unregister from changes in AVPlayer and AVPlayerItem changes
			self.player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate))
			self.player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status))
			self.player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.isPlaybackBufferEmpty))
			self.player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.isPlaybackLikelyToKeepUp))
			self.player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.isExternalPlaybackActive))

			if let timeObserver = self.timeObserver {
				self.player.removeTimeObserver(timeObserver)
				self.timeObserver = nil
			}

			if pictureInPictureRequestIsPending == true {
				pictureInPictureController?
					.removeObserver(self, forKeyPath: #keyPath(AVPictureInPictureController.isPictureInPicturePossible))
			}

			self.isObserving = false
		}
	}

	// swiftlint:disable:next block_based_kvo
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
							   context: UnsafeMutableRawPointer?) {

		guard let path = keyPath else { return }

		switch path {
		case #keyPath(AVPlayer.status):
			if player.status == .readyToPlay {
				delegate?.playerDidTriggerTrackingEvent(self, event: .readyToPlay)
			}
			updateMediaPlayerState()
		case #keyPath(AVPlayer.rate):
			handlePlayerRateChange()
		case #keyPath(AVPlayer.currentItem.isPlaybackBufferEmpty):
			if let bufferEmpty = change?[.newKey] as? Bool {
				handlePlaybackBufferEmptyStateChange(newBufferEmptyState: bufferEmpty)
			}
		case #keyPath(AVPlayer.currentItem.isPlaybackLikelyToKeepUp):
			handleKeepPlayingStateChange()
		case #keyPath(AVPlayer.isExternalPlaybackActive):
			delegate?.playerDidChangeExternalPlayback(self, externalPlaybackActive: player.isExternalPlaybackActive)
		case #keyPath(AVPictureInPictureController.isPictureInPicturePossible):
			handlePipPossibleStateChange()
		default: break
		}
	}

	private func handlePlayerRateChange() {
		if player.rate == 1 {
			delegate?.playerDidTriggerTrackingEvent(self, event: .play)
			ignoreAVPlayerObserversNextFire = true // ignoring the next event in periodical observer because there will be an
												   // because there will be an extra one when rate changes which leads to double
												   // playhead tracking
			isPausedForNielsen = false
		} else if player.rate == 0 && player.status == .readyToPlay && !didReachEnd {
			delegate?.playerDidTriggerTrackingEvent(self, event: .pause)
			ignoreAVPlayerObserversNextFire = true // ignoring the next event (s.a.)
			isPausedForNielsen = true
		}
		updateMediaPlayerState()
	}

	private func handlePlaybackBufferEmptyStateChange(newBufferEmptyState: Bool) {
		if  !isPictureInPictureActive { // strange changes of buffer state during PinP - we ignore that,
										// but it's handled when keep playing state changes
										// (see method handleKeepPlayingStateChange below)
			isBufferEmpty = newBufferEmptyState
			if isBufferEmpty && state == .playing && !didReachEnd {
				isPausedByEmptyBuffer = true
				delegate?.playerDidTriggerTrackingEvent(self, event: .pause)
				isPausedForNielsen = true
			} else if !isBufferEmpty && isPausedByEmptyBuffer {
				delegate?.playerDidTriggerTrackingEvent(self, event: .play)
				isPausedForNielsen = false
				isPausedByEmptyBuffer = false
			} else if didReachEnd && !isPausedByEmptyBuffer {
				didReachEnd = false
			}
		}
		updateMediaPlayerState()
	}

	/**
	 This method mainly tries to handle Nielsen tracking in case of
	 picture-in-picture mode. The implementation is based on  observation
	 during debug.
	 The reason for this specific behaviour during pip remains unclear....
	*/
	private func handleKeepPlayingStateChange() {
		if !isPausedByEmptyBuffer &&
			isPictureInPictureActive &&
			player.currentItem?.isPlaybackBufferEmpty == false {//for strange reason this indicates the start of
																//a bad connection in PiP Mode ...
			isPausedByEmptyBuffer = true
			delegate?.playerDidTriggerTrackingEvent(self, event: .pause)
			isPausedForNielsen = true
		} else if isPictureInPictureActive && isPausedByEmptyBuffer {
			delegate?.playerDidTriggerTrackingEvent(self, event: .play)
			isPausedForNielsen = false
			isPausedByEmptyBuffer = false
		}
		isBufferEmpty = false
		updateMediaPlayerState()
	}

	private func handlePipPossibleStateChange() {
		DispatchQueue.main.async { [weak self] in
			guard self?.pictureInPictureController?.isPictureInPicturePossible == true else { return }
			if self?.pictureInPictureRequestIsPending == true {
				self?.pictureInPictureController?.startPictureInPicture()
				self?.play()
				self?.pictureInPictureRequestIsPending = false
				if let this = self {
					self?.pictureInPictureController?
						.removeObserver(this, forKeyPath: #keyPath(AVPictureInPictureController.isPictureInPicturePossible))
				}
			}
		}
	}

	/// if a `pendingSeekRequestValue` has been stored, execute the seek now
	private func handlePendingLiveSeek() {
		if let seekableRange = seekableRange, let pendingSeek = pendingSeekRequestValue, seekableRange.start.flags.contains(.valid) {
			seekTo(position: pendingSeek.position, completion: pendingSeek.completion)
			pendingSeekRequestValue = nil
		}
	}

	private func startItemObservingIfNotNil(item: AVPlayerItem?) {
		guard let item = item else { return }
		startItemObserving(on: item)
	}

	private func stopItemObservingIfNotNil(item: AVPlayerItem?) {
		guard let item = item else { return }
		stopItemObserving(on: item)
	}

	private func startItemObserving(on item: AVPlayerItem) {
		guard !isObservingItem else { return }
		isObservingItem = true
		NotificationCenter.default.addObserver(self, selector: #selector(MediaPlayerController.playerItemDidFinishPlaying(_:)),
											   name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
		NotificationCenter.default.addObserver(self, selector: #selector(MediaPlayerController.playerItemTimeDidJump(_:)),
											   name: NSNotification.Name.AVPlayerItemTimeJumped, object: item)
	}

	private func stopItemObserving(on item: AVPlayerItem) {
		isObservingItem = false
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
	}

	/// Starts observing if the video playback is still active and trigger a ZDF tracking event if so.
	/// Since the refresh interval is defined in the associated Teasers tracking model, this function needs to be public
	/// and has to be called the MediaTrackingDelegate when the user starts playback.
	func startPlaybackObserving(interval: TimeInterval) {
		if playbackActiveObserver != nil {
			stopPlaybackActiveObserving()
		}
		playbackActiveObserver = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { [weak self] _ in
			guard let this = self else { return }
			if this.state == .playing {
				this.delegate?.playerDidTriggerTrackingEvent(this, event: .playbackActive)
			}
		})
		ignoreAVPlayerObserversNextFire = true  // ignoring the next event in periodical observer because there will be an
												// because there will be an extra one when player starts which leads to double
												// playhead tracking
	}

	private func resetPlaybackActiveObserver() {
		guard let observer = playbackActiveObserver else { return }
		let interval = observer.timeInterval
		observer.invalidate()
		playbackActiveObserver = nil
		startPlaybackObserving(interval: interval)
	}

	private func stopPlaybackActiveObserving() {
		playbackActiveObserver?.invalidate()
		playbackActiveObserver = nil
		ignoreAVPlayerObserversNextFire = true // ignoring the next event in periodical observer because there will be an
											   // because there will be an extra one when player stops which leads to double
											   // playhead tracking
	}

	@objc dynamic fileprivate func playerItemTimeDidJump(_ notification: Notification) {
		delegate?.playerItemTimeDidJump(self, currentTime: currentTimeInSeconds)
	}

	@objc dynamic fileprivate func playerItemDidFinishPlaying(_ notification: Notification) {
		stopPlaybackActiveObserving()
		updateMediaPlayerState()
		delegate?.playerDidTriggerTrackingEvent(self, event: .didReachEnd)
		didReachEnd = true
		delegate?.playerItemDidFinishPlaying(self, asset: asset)
	}


	// MARK: Tracking Special

	/// Special code for (nearly) correct tracking for Nielsen
	/// With the following code we  try to adopt strange behaviour of player during seekable live streams,
	/// in order to provide a tracking for user experience and user interaction, as close as possible
	/// to that thing some call 'The Truth'

	private var ignoreAVPlayerObserversNextFire = true
	private var lastTrackedPlayhead = -1.0
	private(set) var isPausedForNielsen = false

	private func trackPlayhead(for currentItem: AVPlayerItem, and currentTime: CMTime) {
		let playheadPosition: Double
		switch currentItem.playbackType {
		case .vod:
			playheadPosition = currentTime.seconds
		case .seekableLive:
			playheadPosition = seekableLiveStreamStatus.playheadPosition()
		case .live:
			playheadPosition = Date().timeIntervalSince1970  // with non-seekable live streams playhead is now-time
		}

		if shouldTrackPlayhead(with: playheadPosition) {
			delegate?.playerDidTriggerTrackingEvent(self, event: .playhead(position: Int64(playheadPosition)))
			lastTrackedPlayhead = playheadPosition
		} else {
			ignoreAVPlayerObserversNextFire = false
		}
	}


	/// It has been observed, that sometimes it's  neccessary to supress playhead tracking:
	/// 1. The corresponding observer is not only called periodically,but also whenever one
	///   of start / stop / pause / resume is called by user interaction or by special situations
	///   like loss of network connection. Handled by 'ignoreAVPlayerObserversNextFire'
	/// 2. If the prepared state isn't 'prepared', but the obersver is already running
	/// 3. When a discontinouus playhead was reported or calculated, which means it is
	///   smaller then the previous one AND isn't small enough, that this could mean
	///   it's a back seeking.
	private func shouldTrackPlayhead(with playheadPosition: Double) -> Bool {
		return !ignoreAVPlayerObserversNextFire
		&& preparedState == .prepared
		&& (playheadPosition > lastTrackedPlayhead || abs(playheadPosition - lastTrackedPlayhead) > 3.0)
	}

// swiftlint:disable:next file_length
}
