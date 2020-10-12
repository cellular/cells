// Created on 10.10.20

import UIKit

class MultiPlayerViewController: UIViewController {

	@IBOutlet weak var playerView: CellsPlayerView!
	@IBOutlet weak var miniPlayerView: CellsPlayerView!
	@IBOutlet weak var mediPlayerView: CellsPlayerView!
	
	let playerController = MediaPlayerController<CellsMediaAsset>(configuration: .init())

	override func viewDidLoad() {
		super.viewDidLoad()
			
		playerController.attach(view: playerView)
		playerController.attach(view: miniPlayerView)
		playerController.attach(view: mediPlayerView)
		
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
}
