// Created on 07.11.20

import UIKit

class ModelDataSourceViewController: UIViewController {
	
	@IBOutlet weak var tableView: UITableView!
	
	private var dataSource: TableViewDataSource = TableViewDataSource()

	
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
		tableView?.dataSource = dataSource
		tableView?.register(ModelDataSourceTableViewCell.self)
	}

	
	// MARK: Content Setup
	let testInhalt: [Inhalt] = [
		.init(bild: UIImage(systemName: "leaf.fill"), beschreibung: "Blatt"),
		.init(bild: UIImage(systemName: "moon.circle.fill"), beschreibung: "Mond"),
		.init(bild: UIImage(systemName: "airplane.circle.fill"), beschreibung: "Flugzeug"),
		.init(bild: UIImage(systemName: "sun.max.fill"), beschreibung: "Sonne"),
	]
	
	private func fillWithContent() {
		dataSource.removeAll()
		dataSource.append(section: .init())
		
		testInhalt.forEach { inhaltsItem in
			dataSource.append(item: .init(model: inhaltsItem, cell: ModelDataSourceTableViewCell.self))
		}
		tableView.reloadData()
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
		dataSource.removeAll()
		dataSource.append(section: .init())
		
		updatedInhalt.forEach { inhaltsItem in
			dataSource.append(item: .init(model: inhaltsItem, cell: ModelDataSourceTableViewCell.self))
		}
		tableView.reloadData()
	}
}
