// Created on 09.10.20

import Foundation

struct CellsMediaAsset: MediaAsset {
	var mimeType: String?
	
	let url: URL
	
	var identifier: String {
		return url.absoluteString
	}
}
