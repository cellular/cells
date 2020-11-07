// Created on 07.11.20

import UIKit

final class BeispielInhaltTableViewCell: UITableViewCell {

	@IBOutlet weak var bildSicht: UIImageView!
	@IBOutlet weak var etikett: UILabel!
	
	var model: Inhalt? {
		didSet {
			bildSicht.image = model?.bild?.withRenderingMode(.alwaysOriginal)
			etikett.text = model?.beschreibung
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
	}
}
