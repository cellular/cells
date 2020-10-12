// Created on 10.10.20

import UIKit
import AVKit

class PipPlayerViewController: UIViewController {

	@IBOutlet weak var playerView: CellsPlayerView!
	@IBOutlet weak var debugLabel: UILabel!
	
	let playerController = MediaPlayerController<CellsMediaAsset>(configuration: .init())

	override func viewDidLoad() {
		super.viewDidLoad()
			
		let audioSession = AVAudioSession.sharedInstance()
				
				do {
					try audioSession.setCategory(AVAudioSession.Category.playback)
				} catch  {
					print("Audio session failed")
				}
		
		playerController.attach(view: playerView)
		
		let asset = CellsMediaAsset(mimeType: nil, url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!)
		playerController.setAsset(asset)
		playerController.play()
	}
	
	@IBAction func didTapPlay(_ sender: Any) {
		playerController.play()
	}
	
	@IBAction func didTapPause(_ sender: Any) {
		playerController.pause()
	}
	
	@IBAction func didTapPip(_ sender: Any) {
		playerController.startPictureInPicture(on: playerView, delegate: self)
	}
}

extension PipPlayerViewController: AVPictureInPictureControllerDelegate {
	func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
		print(error.localizedDescription)
		debugLabel.text = error.localizedDescription
	}
}
