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
import Firebase
import Mixpanel

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
        let dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            switch item {
            case .friendRequestItem(notifications: let notifications):
                let cell = tableView.dequeueReusableCell(withIdentifier: FriendRequestCollectionCell.reuseID, for: indexPath) as? FriendRequestCollectionCell
                cell?.setValues(notifications: notifications)
                cell?.delegate = self
                return cell ?? UITableViewCell()

            case .activityItem(notification: let notification):
                switch NotificationType(rawValue: notification.type) {
                case .contactJoin:
                    let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseID, for: indexPath) as? ContactCell
                    if let user = notification.userInfo {
                        let friendStatus: FriendStatus = (user.contactInfo?.pending ?? false) ? .pending : .none
                        cell?.setUp(contact: user, friendStatus: friendStatus, cellType: .notifications)
                    }
                    cell?.delegate = self
                    return cell

                default:
                    let cell = tableView.dequeueReusableCell(withIdentifier: ActivityCell.reuseID, for: indexPath) as? ActivityCell
                    cell?.configure(notification: notification)
                    cell?.delegate = self
                    return cell
                }
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

        edgesForExtendedLayout = []
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "NotificationsAppeared")
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
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.color = .white
        activityIndicator.startAnimating()

        // get contacts to ID user's who sent friend requests
        if ContactsFetcher.shared.contactsAuth == .authorized {
            ContactsFetcher.shared.getContacts()
        }

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

        NotificationCenter.default.addObserver(self, selector: #selector(acceptedFriendRequest(_:)), name: NSNotification.Name(rawValue: "AcceptedFriendRequest"), object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpNavBar() {
        navigationController?.setUpOpaqueNav(backgroundColor: SpotColors.SpotBlack.color)
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: SpotFonts.UniversCE.fontWith(size: 20)
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
        return 34
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
            Mixpanel.mainInstance().track(event: "NotificationsPaginationTriggered")
            isRefreshingPagination = true
            refresh.send(true)
        }

        // set seen for activity notis only
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        switch item {
        case .activityItem(let noti):
            viewModel.setSeenFor(notiID: noti.id ?? "")
        case .friendRequestItem(_):
            return
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let snapshot = datasource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        switch item {
        case .activityItem(let noti):
            switch NotificationType(rawValue: noti.type) {
            case .friendRequest:
                if let userProfile = noti.userInfo {
                    Mixpanel.mainInstance().track(event: "NotificationsFriendRequestNotificationTap")
                    openProfile(userProfile: userProfile)
                }
            default:
                Mixpanel.mainInstance().track(event: "NotificationsActivityNotificationTap")
                if let spot = noti.spotInfo {
                    openSpot(spot: spot)
                }
            }

        case .friendRequestItem(_):
            return
        }
    }

    private func openProfile(userProfile: UserProfile) {
        let vc = ProfileViewController(viewModel: ProfileViewModel(serviceContainer: ServiceContainer.shared, profile: userProfile))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    private func openSpot(spot: MapSpot) {
        let vc = SpotController(viewModel: SpotViewModel(serviceContainer: ServiceContainer.shared, spot: spot))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func acceptedFriendRequest(_ notification: NSNotification) {
        if let notiID = notification.userInfo?.values.first as? String {
            if var noti = viewModel.cachedFriendRequestNotifications.first(where: { $0.id == notiID }) {
                noti.seen = true
                noti.status = NotificationStatus.accepted.rawValue
                noti.timestamp = Timestamp()

                viewModel.cachedFriendRequestNotifications.removeAll(where: { $0.id == notiID })
                viewModel.cachedActivityNotifications.insert(noti, at: 0)

                refresh.send(false)
            }
        }
    }
}

extension NotificationsViewController: ContactCellDelegate {
    func contactCellProfileTap(user: UserProfile) {
        openProfile(userProfile: user)
    }

    func addFriend(user: UserProfile) {
        if let userID = user.id, let i = viewModel.cachedActivityNotifications.firstIndex(where: { $0.type == NotificationType.contactJoin.rawValue
            && $0.senderID == user.id ?? "" }) {

            viewModel.cachedActivityNotifications[i].userInfo?.contactInfo?.pending = true
            refresh.send(false)

            viewModel.addFriend(receiverID: userID)
            viewModel.removeContactNotification(notiID: viewModel.cachedActivityNotifications[i].id ?? "")
        }
    }

    func removeSuggestion(user: UserProfile) {
        if let userID = user.id, let i = viewModel.cachedActivityNotifications.firstIndex(where: { $0.type == NotificationType.contactJoin.rawValue && $0.senderID == user.id ?? "" }) {
            let notiID = viewModel.cachedActivityNotifications[i].id ?? ""
            
            viewModel.cachedActivityNotifications.remove(at: i)
            refresh.send(false)

            viewModel.removeContactNotification(notiID: notiID)
            viewModel.removeSuggestion(userID: userID)
        }
    }
}

extension NotificationsViewController: ActivityCellDelegate {
    func activityCellProfileTap(userProfile: UserProfile) {
        openProfile(userProfile: userProfile)
    }
}

extension NotificationsViewController: FriendRequestCollectionDelegate {
    func friendRequestCellProfileTap(userProfile: UserProfile) {
        openProfile(userProfile: userProfile)
    }

    func deleteFriendRequest(friendRequest: UserNotification) -> [UserNotification] {
        if let i = viewModel.cachedFriendRequestNotifications.firstIndex(where: { $0.id == friendRequest.id }) {
            viewModel.cachedFriendRequestNotifications.remove(at: i)
        }
        return viewModel.cachedFriendRequestNotifications.elements
    }

    func reloadTable() {
        refresh.send(false)
    }
}
