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
}



extension BeispielInhaltTableViewCell: SugaredTableViewCell {
	static var source: CellSource<BeispielInhaltTableViewCell> {
		return .nib(UINib(nibName: String(describing: BeispielInhaltTableViewCell.self), bundle: nil))
	}
}
