// Created on 07.11.20

import UIKit

/// Example usage of UITableViewDiffableDataSource with syntactic sugar
final class SugaredDiffableDatasourceViewController: UIViewController {

	@IBOutlet weak var tableView: UITableView!
	
	// UITableViewDiffableDataSource is available since iOS 13.0
	lazy var datasource: UITableViewDiffableDataSource<Abschnitt, Inhalt> = makeDataSource()
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupTableView()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		fillWithContent()
	}
	
	
	
	// MARK: Setup
	private func setupTableView() {
		tableView.dataSource = datasource
		tableView.register(BeispielInhaltTableViewCell.self)
	}
	
	private func makeDataSource() -> UITableViewDiffableDataSource<Abschnitt, Inhalt> {
		return UITableViewDiffableDataSource(tableView: tableView) { (tableView, indexPath, inhaltItem) -> UITableViewCell? in
			return tableView.makeModelCell(BeispielInhaltTableViewCell.self, indexPath: indexPath, model: inhaltItem)
		}
	}
	
	
	
	
	
	
	
	
	
	
	// MARK: Content Setup
	let testInhalt: [Inhalt] = [
		.init(bild: UIImage(systemName: "leaf.fill"), beschreibung: "Blatt"),
		.init(bild: UIImage(systemName: "moon.circle.fill"), beschreibung: "Mond"),
		.init(bild: UIImage(systemName: "airplane.circle.fill"), beschreibung: "Flugzeug"),
		.init(bild: UIImage(systemName: "sun.max.fill"), beschreibung: "Sonne"),
	]
	
	private func fillWithContent() {
		var snapshot = NSDiffableDataSourceSnapshot<Abschnitt, Inhalt>()
		snapshot.appendSections([.eins])
		snapshot.appendItems(testInhalt)
		
		datasource.apply(snapshot)
	}
	
	
	
	
	
	// MARK: Content Update
	let updatedInhalt: [Inhalt] = [
		.init(bild: UIImage(systemName: "sun.max.fill"), beschreibung: "Sonne"), // moved item
		.init(bild: UIImage(systemName: "leaf.fill"), beschreibung: "Blatt"),
		.init(bild: UIImage(systemName: "moon.circle.fill"), beschreibung: "Mond"),
		.init(bild: UIImage(systemName: "star.fill"), beschreibung: "Stern") // new item
		// "Flugzeug" was removed
	]
	
	private func fillWithUpdatedContent() {
		var snapshot = NSDiffableDataSourceSnapshot<Abschnitt, Inhalt>()
		snapshot.appendSections([.eins])
		snapshot.appendItems(updatedInhalt)
		
		datasource.apply(snapshot)
	}
	
	
	
	
	
	
	// MARK: UI
	var isShowingInitialContent = true
	@IBAction func didTapToggleModelButton(_ sender: Any) {
		if isShowingInitialContent {
			fillWithUpdatedContent()
		} else {
			fillWithContent()
		}
		isShowingInitialContent.toggle()
	}
	
}
