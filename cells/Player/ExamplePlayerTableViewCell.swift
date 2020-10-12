// Created on 10.10.20

import UIKit

class ExamplePlayerTableViewCell: UITableViewCell {
	
	func update(with player: ExamplePlayer) {
		textLabel?.text = player.rawValue
		imageView?.image = player.icon
		accessoryType = .disclosureIndicator
	}
}
