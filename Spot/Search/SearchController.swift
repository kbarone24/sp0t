//
//  SearchController.swift
//  Spot
//
//  Created by Kenny Barone on 6/15/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Combine
import Foundation
import UIKit

class SearchController: UIViewController {
    typealias Input = SearchViewModel.Input
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    private let viewModel: SearchViewModel
    private let searchText = PassthroughSubject<String, Never>()
    private var subscriptions = Set<AnyCancellable>()

    private lazy var dataSource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .item(let searchResult):
                let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultCell.reuseID, for: indexPath) as? SearchResultCell
                cell?.configure(searchResult: searchResult)
                return cell
            }
        }
        return dataSource
    }()

    enum Section: Hashable {
        case main
    }

    enum Item: Hashable {
        case item(searchResult: SearchResult)
    }

    private(set) lazy var searchBarContainer = UIView()
    private(set) lazy var searchBar: UISearchBar = {
        let searchBar = SpotSearchBar()
        searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search Maps",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)]
        )
        searchBar.keyboardDistanceFromTextField = 250
        return searchBar
    }()

    lazy var tableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = UIColor(named: "SpotBlack")
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseID)
        table.rowHeight = 40
        return table
    }()

    private(set) lazy var activityIndicator = UIActivityIndicatorView()
    
    init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(named: "SpotBlack")
        // search bar as title view?
        searchBarContainer.backgroundColor = nil
        view.addSubview(searchBarContainer)
        searchBarContainer.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(20)
            $0.height.equalTo(50)
        }

        searchBar.delegate = self
        searchBarContainer.addSubview(searchBar)
        searchBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.top.equalTo(6)
            $0.height.equalTo(36)
        }

        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(searchBarContainer.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(tableView).offset(100)
            $0.width.height.equalTo(30)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)

        let input = Input(searchText: searchText)
        let output = viewModel.bind(to: input)

        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
                self?.activityIndicator.stopAnimating()
                print("sink", snapshot.numberOfItems)
            }
            .store(in: &subscriptions)
    }

    private func setUpNavBar() {
        navigationController?.setUpDarkNav(translucent: false)
    }
}

extension SearchController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText.send(searchText)
        DispatchQueue.main.async {
            self.activityIndicator.startAnimating()
        }
    }
}

extension SearchController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.snapshot().numberOfItems
    }
}
