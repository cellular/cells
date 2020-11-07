// Created on 07.11.20

import UIKit

// 'SectionIdentifierType: Hashable'
enum Abschnitt: Hashable {
	case eins
	case zwei
}

// 'ItemIdentifierType: Hashable'
struct Inhalt: Hashable {
	let bild: UIImage?
	let beschreibung: String
}

let testInhalt: [Inhalt] = [
	.init(bild: UIImage(systemName: "leaf.fill"), beschreibung: "Blatt"),
	.init(bild: UIImage(systemName: "moon.circle.fill"), beschreibung: "Mond"),
	.init(bild: UIImage(systemName: "airplane.circle.fill"), beschreibung: "Flugzeug"),
	.init(bild: UIImage(systemName: "sun.max.fill"), beschreibung: "Sonne"),
]

class DiffableDatasourceViewController: UIViewController {

	@IBOutlet weak var tableView: UITableView!
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
		tableView.register(UINib(nibName: "BeispielInhaltTableViewCell", bundle: nil), forCellReuseIdentifier: "zelle")
		tableView.dataSource = datasource
	}
	
	private func makeDataSource() -> UITableViewDiffableDataSource<Abschnitt, Inhalt> {
		return UITableViewDiffableDataSource(tableView: tableView) { (tableView, indexPath, inhaltItem) -> UITableViewCell? in
			/// similar to cellForItemAtIndexPath: we have `tableView` and `indexPath`
			let cell = tableView.dequeueReusableCell(withIdentifier: "zelle", for: indexPath) as? BeispielInhaltTableViewCell
			
			/// nice: we have direct reference to `inhaltItem`
			cell?.updateForContent(inhalt: inhaltItem)
			
			return cell
		}
	}
	
	
	
	// MARK: Content
	private func fillWithContent() {
		var snapshot = NSDiffableDataSourceSnapshot<Abschnitt, Inhalt>()
		snapshot.appendSections([.eins])
		snapshot.appendItems(testInhalt)
		
		datasource.apply(snapshot)
	}
}
