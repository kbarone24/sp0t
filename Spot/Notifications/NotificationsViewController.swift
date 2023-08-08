//
//  NotificationsViewController.swift
//  Spot
//
//  Created by Kenny Barone on 8/8/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Combine

class NotificationsViewController: UIViewController {
    enum Section: Hashable {
        case friendRequest(title: String)
        case activity(title: String)
    }

    enum Item: Hashable {
        case activityItem(notification: UserNotification)
        case friendRequestItem(notifications: [UserNotification])
    }

    typealias Input = NotificationsViewModel.Input
    typealias Output = NotificationsViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    let viewModel: NotificationsViewModel
    var subscriptions = Set<AnyCancellable>()

    let refresh = PassthroughSubject<Bool, Never>()

    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .friendRequestItem(notifications: let notifications):
                let cell = tableView.dequeueReusableCell(withIdentifier: FriendRequestCollectionCell.reuseID, for: indexPath) as? FriendRequestCollectionCell
                cell?.setValues(notifications: notifications)
                return cell

            case .activityItem(notification: let notification):
                let cell = tableView.dequeueReusableCell(withIdentifier: ActivityCell.reuseID, for: indexPath) as? ActivityCell
                cell?.configure(notification: notification)
                return cell
            }
        }
        return dataSource
    }()

    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.backgroundColor = SpotColors.SpotBlack.color
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        tableView.clipsToBounds = true
        tableView.register(FriendRequestCollectionCell.self, forCellReuseIdentifier: FriendRequestCollectionCell.reuseID)
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseID)
        tableView.register(ActivityCell.self, forCellReuseIdentifier: ActivityCell.reuseID)
        tableView.register(NotificationsTableHeader.self, forHeaderFooterViewReuseIdentifier: NotificationsTableHeader.reuseID)
        return tableView
    }()

    private lazy var activityIndicator = UIActivityIndicatorView()

    var isRefreshingPagination = false {
        didSet {
            DispatchQueue.main.async {
                if self.isRefreshingPagination, !self.datasource.snapshot().itemIdentifiers.isEmpty {
                    self.tableView.layoutIfNeeded()
                    let tableBottom = self.tableView.contentSize.height
                    self.activityIndicator.snp.removeConstraints()
                    self.activityIndicator.snp.makeConstraints {
                        $0.centerX.equalToSuperview()
                        $0.width.height.equalTo(30)
                        $0.top.equalTo(tableBottom + 15)
                    }
                    self.activityIndicator.startAnimating()
                }
            }
        }
    }


    init(viewModel: NotificationsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SpotColors.SpotBlack.color

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(100)
            $0.width.height.equalTo(30)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.startAnimating()

        let input = Input(refresh: refresh)

        let output = viewModel.bind(to: input)
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)
                self?.activityIndicator.stopAnimating()
                self?.isRefreshingPagination = false
            }
            .store(in: &subscriptions)

        refresh.send(true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpNavBar() {
        navigationController?.setUpDarkNav(translucent: false)
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont(name: "UniversCE-Black", size: 19) as Any
        ]
        navigationItem.title = "Notifications"
    }
}

extension NotificationsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !datasource.snapshot().sectionIdentifiers.isEmpty else { return UIView() }
        let section = datasource.snapshot().sectionIdentifiers[section]
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: NotificationsTableHeader.reuseID) as? NotificationsTableHeader

        switch section {
        case .friendRequest(title: let title):
            header?.configure(title: title)

        case .activity(title: let title):
            header?.configure(title: title)
        }

        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = datasource.snapshot().sectionIdentifiers[indexPath.section]
        switch section {
        case.friendRequest(title: _): return 205
        case .activity(title: _): return 70
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let snapshot = datasource.snapshot()
        if (indexPath.row >= snapshot.numberOfItems - 2) && !isRefreshingPagination, !viewModel.disablePagination {
            isRefreshingPagination = true
            refresh.send(true)
        }

        // TODO: set seen for noti
    }
}

extension NotificationsViewController: NotificationsDelegate, ContactCellDelegate {
    func deleteFriendRequest(friendRequest: UserNotification) -> [UserNotification] {
        return []
    }

    func getProfile(userProfile: UserProfile) {

    }

    func deleteFriend(friendID: String) {

    }

    func reloadTable() {

    }

    func openProfile(user: UserProfile) {

    }

    func addFriend(user: UserProfile) {

    }

    func removeSuggestion(user: UserProfile) {

    }
}
