// Created on 07.11.20

import UIKit

final class ModelDataSourceTableViewCell: UITableViewCell, ModelDataSourceViewDisplayable {

	static var source: Source<ModelDataSourceTableViewCell> {
		return .nib(UINib(nibName: String(describing: ModelDataSourceTableViewCell.self), bundle: nil))
	}

	var model: Inhalt? {
		didSet {
			textLabel?.text = model?.beschreibung
			imageView?.image = model?.bild
		}
	}
}
