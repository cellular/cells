// Created on 09.10.20

import Foundation

extension MediaPlayerController {
	struct Configuration {
		/// custom value for the 'User-Agent' HTTP-Header, which shall be used when loading AVURLAssets for the player
		let customUserAgent: String?

		init(customUserAgent: String? = nil) {
			self.customUserAgent = customUserAgent
		}
	}
}
