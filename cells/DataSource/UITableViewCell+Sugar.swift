// Created on 07.11.20

import UIKit

/// MARK: POC extensions to make vanilla UITableView API similarly convenient to ModelDataSource
/// Extensions are based on ModelDataSource, but may not have equivalent feature set, since this is only a POC

enum CellSource<T: SugaredTableViewCell> {
	case view(T.Type)
	case nib(UINib)
	case prototype
}

protocol SugaredTableViewCell {
	
	/// The model class to be associated with the cell.
	associatedtype Model
	
	/// The source file of the decorative view. Used to register/dequeue & calculate size of the receiver.
	static var source: CellSource<Self> { get }
	
	/// Model that was associated with the cell on initialization or reuse.
	var model: Model? { get set }
}

extension SugaredTableViewCell {
	
	/// Defaults to the class name of the view. Raw class name only, no module or hash attached.
	public static var reuseIdentifier: String {
		return String(describing: self)
	}
}

extension UITableView {

	/// Allows to register classes of model data source view cells directly with their
	/// appropriate reuse identifier and their source file defintion (class or nib).
	///
	/// - Parameter cell: The cell type which should be registered to the table view.
	func register<C>(_ cell: C.Type) where C: UITableViewCell, C: SugaredTableViewCell {
		switch cell.source {
		case let .view(viewClass):
			self.register(viewClass, forCellReuseIdentifier: cell.reuseIdentifier)
		case let .nib(nib):
			self.register(nib, forCellReuseIdentifier: cell.reuseIdentifier)
		case .prototype:
			break // Skip, prototype cells are already registered within the storyboard
		}
	}
}

extension BeispielInhaltTableViewCell: SugaredTableViewCell {
	static var source: CellSource<BeispielInhaltTableViewCell> {
		return .nib(UINib(nibName: String(describing: BeispielInhaltTableViewCell.self), bundle: nil))
	}
}

// very similar to UICollectionView.CellRegistration (iOS 14)
extension UITableView {
	func makeModelCell<C: SugaredTableViewCell>(_ cell: C.Type, indexPath: IndexPath, model: C.Model) -> C? {
		var cell = dequeueReusableCell(withIdentifier: C.reuseIdentifier, for: indexPath) as? C
		cell?.model = model
		return cell
	}
}
