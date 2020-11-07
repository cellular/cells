// Created on 07.11.20

import UIKit

class BeispielInhaltTableViewCell: UITableViewCell {

	@IBOutlet weak var bildSicht: UIImageView!
	@IBOutlet weak var etikett: UILabel!
	
    override func awakeFromNib() {
        super.awakeFromNib()
    }
	
	func updateForContent(inhalt: Inhalt) {
		bildSicht.image = inhalt.bild?.withRenderingMode(.alwaysOriginal)
		etikett.text = inhalt.beschreibung
	}
}
