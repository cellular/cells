// Created on 10.10.20

import UIKit

class ExampleListViewController: UIViewController, UITableViewDelegate {
	enum Section: CaseIterable {
		case first
	}
	
	@IBOutlet weak var tableView: UITableView!
	lazy var dataSource = makeDataSource()
	private static let cellIdentifier = "exampleCell"
	
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.title = "Example Players"
		navigationController?.navigationBar.prefersLargeTitles = true
		
		tableView.dataSource = dataSource
		tableView.delegate = self
		tableView.register(ExamplePlayerTableViewCell.self, forCellReuseIdentifier: Self.cellIdentifier)
		
		var snapshot = NSDiffableDataSourceSnapshot<Section, ExamplePlayer>()
		snapshot.appendSections(Section.allCases)
		snapshot.appendItems([.basic, .multi, .pip], toSection: .first)
		dataSource.apply(snapshot)
	}
	
	private func makeDataSource() -> UITableViewDiffableDataSource<Section, ExamplePlayer> {
		UITableViewDiffableDataSource(tableView: tableView) { (tableView, indexPath, player) -> UITableViewCell? in
			let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath) as! ExamplePlayerTableViewCell
			cell.update(with: player)
			return cell
		}
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard let player = dataSource.itemIdentifier(for: indexPath) else { return }
		guard let vc = player.viewController else { return }
		navigationController?.pushViewController(vc, animated: true)
	}
}
