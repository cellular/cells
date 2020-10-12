// Created on 09.10.20

import UIKit

final class BasicPlayerViewController: UIViewController {
	
	@IBOutlet weak var playerView: CellsPlayerView!
	
	let playerController = MediaPlayerController<CellsMediaAsset>(configuration: .init())

    override func viewDidLoad() {
        super.viewDidLoad()
			
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
}
