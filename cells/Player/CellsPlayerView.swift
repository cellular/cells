// Created on 09.10.20

import UIKit
import AVKit

public final class CellsPlayerView: UIView {
	// Override UIView property - needed to set an AVPlayer
	override public static var layerClass: AnyClass {
		return AVPlayerLayer.self
	}
	
}
