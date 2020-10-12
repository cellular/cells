// Created on 10.10.20

import UIKit

enum ExamplePlayer: String {
	case basic = "Basic Player"
	case pip = "Picture In Picture"
	case multi = "Multiple PlayerViews"
	
	var icon: UIImage? {
		switch self {
		case .basic:
			return UIImage(systemName: "display")
		case .pip:
			return UIImage(systemName: "pip")
		case .multi:
			return UIImage(systemName: "display.2")
		}
	}
	
	var viewController: UIViewController? {
		switch self {
		case .basic:
			return UIStoryboard(name: "Player", bundle: nil).instantiateViewController(identifier: "BasicPlayerViewController")
		case .pip:
			return UIStoryboard(name: "Player", bundle: nil).instantiateViewController(identifier: "PipPlayerViewController")
			
		case .multi:
			return UIStoryboard(name: "Player", bundle: nil).instantiateViewController(identifier: "MultiPlayerViewController")
		}
	}
}
