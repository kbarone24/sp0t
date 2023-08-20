//
//  HomeScreenController.swift
//  Spot
//
//  Created by Kenny Barone on 7/6/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Combine
import Mixpanel
import CoreLocation
import GeoFireUtils

class HomeScreenController: UIViewController {
    enum SectionType {
        case Hot
        case Nearby
    }

    enum Section: Hashable {
        case top(title: String)
        case nearby(title: String)
    }

    enum Item: Hashable {
        case item(spot: MapSpot)
    }

    typealias Input = HomeScreenViewModel.Input
    typealias Output = HomeScreenViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    let viewModel: HomeScreenViewModel
    var subscriptions = Set<AnyCancellable>()

    let refresh = PassthroughSubject<Bool, Never>()

    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            switch item {
            case .item(spot: let spot):
                let cell = tableView.dequeueReusableCell(withIdentifier: HomeScreenSpotCell.reuseID, for: indexPath) as? HomeScreenSpotCell
                cell?.configure(spot: spot)
                return cell
            }
        }
        return dataSource
    }()

    private lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "HomeScreenBackground"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.rowHeight = 130
        tableView.estimatedRowHeight = 130
        tableView.backgroundColor = nil
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 50, right: 0)
        tableView.clipsToBounds = true
        tableView.automaticallyAdjustsScrollIndicatorInsets = true
        tableView.register(HomeScreenSpotCell.self, forCellReuseIdentifier: HomeScreenSpotCell.reuseID)
        tableView.register(HomeScreenTableHeader.self, forHeaderFooterViewReuseIdentifier: HomeScreenTableHeader.reuseID)
        return tableView
    }()

    private lazy var footerView: HomeScreenTableFooter = {
        let view = HomeScreenTableFooter()
        view.isHidden = true
        view.shareButton.addTarget(self, action: #selector(shareTap), for: .touchUpInside)
        view.refreshButton.addTarget(self, action: #selector(refreshTap), for: .touchUpInside)
        view.inboxButton.addTarget(self, action: #selector(inboxTap), for: .touchUpInside)
        return view
    }()

    private lazy var emptyState = HomeScreenEmptyState()
    private lazy var flaggedState = HomeScreenFlaggedUserState()

    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
        return refreshControl
    }()

    private lazy var activityIndicator = UIActivityIndicatorView()

    private var isRefreshing = false {
        didSet {
            DispatchQueue.main.async {
                if self.isRefreshing {
                    self.activityIndicator.snp.removeConstraints()
                    self.view.bringSubviewToFront(self.activityIndicator)
                    self.activityIndicator.snp.makeConstraints {
                        $0.centerX.equalToSuperview()

                        if self.tapToRefresh {
                            $0.bottom.equalTo(self.footerView.snp.top).offset(30)
                        } else {
                            $0.top.equalTo(60)
                        }
                    }

                    self.activityIndicator.startAnimating()

                } else {
                    self.activityIndicator.stopAnimating()
                }
            }
        }
    }

    private var tapToRefresh = false

    private lazy var titleView: HomeScreenTitleView = {
        let view = HomeScreenTitleView()
        view.searchButton.addTarget(self, action: #selector(searchTap), for: .touchUpInside)
        view.profileButton.shadowButton.addTarget(self, action: #selector(profileTap), for: .touchUpInside)
        view.notificationsButton.addTarget(self, action: #selector(notificationsTap), for: .touchUpInside)
        return view
    }()


    init(viewModel: HomeScreenViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        addNotifications()

        view.backgroundColor = .white
        edgesForExtendedLayout = []
    }

    deinit {
        print("home screen deinit")
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // fetch user data
        checkLocationAuth()
        UserDataModel.shared.addListeners()
        subscribeToNotiListener()
        subscribeToChatListener()

        view.addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        // setup view
        tableView.refreshControl = refreshControl
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.leading.bottom.trailing.top.equalToSuperview()
        }

        view.addSubview(emptyState)
        emptyState.isHidden = true
        emptyState.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(flaggedState)
        flaggedState.isHidden = true
        flaggedState.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(footerView)
        footerView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(150)
        }

        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(60)
        }
        activityIndicator.color = .white
        activityIndicator.transform = CGAffineTransform(scaleX: 1.75, y: 1.75)
        activityIndicator.startAnimating()

        let input = Input(
            refresh: refresh
        )

        let output = viewModel.bind(to: input)
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)
                self?.tableView.invalidateIntrinsicContentSize()
                self?.refreshControl.endRefreshing()
                self?.activityIndicator.stopAnimating()
                self?.isRefreshing = false
                self?.footerView.isHidden = false

                if UserDataModel.shared.userInfo.flagged {
                    self?.addFlaggedState()
                } 

                if snapshot.itemIdentifiers.isEmpty {
                    self?.addEmptyState()
                } else {
                    self?.emptyState.isHidden = true
                }

                // scroll to first row on forced refresh
                if self?.tapToRefresh ?? false {
                    self?.tapToRefresh = false
                    if !snapshot.itemIdentifiers.isEmpty {
                        self?.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
                    }
                }
            }
            .store(in: &subscriptions)

        refresh.send(true)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "HomeScreenAppeared")

        if !datasource.snapshot().itemIdentifiers.isEmpty {
            refreshLocation()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layoutIfNeeded()
      //  addGradient()
    }

    private func addNotifications() {
        // deep link notis sent from SceneDelegate
        NotificationCenter.default.addObserver(self, selector: #selector(gotUserLocation), name: NSNotification.Name("UpdatedLocationAuth"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(gotNotification(_:)), name: NSNotification.Name("IncomingNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyLogout), name: NSNotification.Name("Logout"), object: nil)
    }

    private func setUpNavBar() {
        navigationController?.setUpOpaqueNav(backgroundColor: UIColor(hexString: "70B7FF"))
        navigationItem.titleView = titleView
    }

    private func addEmptyState() {
        guard let locationService = try? ServiceContainer.shared.service(for: \.locationService) else { return }
        guard locationService.currentLocationStatus() != .notDetermined else {
            // actively asking user for location
            return
        }

        emptyState.isHidden = false
        if locationService.currentLocationStatus() != .authorizedWhenInUse {
            emptyState.configureNoAccess()
        } else {
            emptyState.configureNoPosts()
        }
    }

    private func addFlaggedState() {
        titleView.isUserInteractionEnabled = false
        flaggedState.isHidden = false
    }

    private func subscribeToNotiListener() {
        let request = Firestore.firestore()
            .collection(FirebaseCollectionNames.users.rawValue)
            .document(UserDataModel.shared.uid)
            .collection(FirebaseCollectionNames.notifications.rawValue)
            .whereField(FirebaseCollectionFields.seen.rawValue, isEqualTo: false)

        request.snapshotPublisher(includeMetadataChanges: true)
            .removeDuplicates()
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] completion in
                    var docCount = 0
                    //TODO: remove temporary function: check that notification is friend request or has a spot attached to it, remove noti from old version if not
                    for doc in completion.documents {
                        guard let noti = try? doc.data(as: UserNotification.self) else { continue }
                        if noti.spotID ?? "" != "" || noti.type == NotificationType.friendRequest.rawValue || noti.type == NotificationType.contactJoin.rawValue {
                            docCount += 1
                        } else {
                            self?.viewModel.removeDeprecatedNotification(notiID: noti.id ?? "")
                        }
                    }
                    DispatchQueue.main.async {
                        self?.titleView.notificationsButton.pendingCount = docCount
                        self?.navigationItem.titleView = self?.titleView ?? UIView()
                    }
                })
            .store(in: &subscriptions)
    }

    private func subscribeToChatListener() {
        let request = Firestore.firestore()
            .collection(FirebaseCollectionNames.botChat.rawValue)
            .whereField(BotChatCollectionFields.userID.rawValue, isEqualTo: UserDataModel.shared.uid)
            .whereField(BotChatCollectionFields.seenByUser.rawValue, isEqualTo: false)

        request.snapshotPublisher(includeMetadataChanges: true)
            .removeDuplicates()
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] completion in
                    var docCount = 0
                    for doc in completion.documents {
                        guard (try? doc.data(as: BotChatMessage.self)) != nil else { continue }
                        docCount += 1
                    }
                    DispatchQueue.main.async {
                        self?.footerView.inboxButton.hasUnseenNoti = docCount > 0
                    }

                })
            .store(in: &subscriptions)
    }

    @objc func searchTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenSearchTap")
        let vc = SearchController(viewModel: SearchViewModel(serviceContainer: ServiceContainer.shared))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func profileTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenProfileTap")
        let vc = ProfileViewController(viewModel: ProfileViewModel(serviceContainer: ServiceContainer.shared, profile: UserDataModel.shared.userInfo))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func notificationsTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenNotificationsTap")
        openNotifications()
    }

    func openNotifications() {
        let vc = NotificationsViewController(viewModel: NotificationsViewModel(serviceContainer: ServiceContainer.shared))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension HomeScreenController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !datasource.snapshot().sectionIdentifiers.isEmpty else { return UIView() }
        let section = datasource.snapshot().sectionIdentifiers[section]
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: HomeScreenTableHeader.reuseID) as? HomeScreenTableHeader

        switch section {
        case .top(title: let title):
            header?.configure(title: title)

        case .nearby(title: let title):
            header?.configure(title: title)
        }

        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 34
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = datasource.snapshot().sectionIdentifiers[indexPath.section]
        let item = datasource.snapshot().itemIdentifiers(inSection: section)[indexPath.item]
        switch item {
        case .item(spot: let spot):
            viewModel.setSeenLocally(spot: spot)
            refresh.send(false)
            openSpot(spot: spot, postID: nil, commentID: nil)
            
            switch section {
            case .top(title: _):
                Mixpanel.mainInstance().track(event: "HomeScreenHotSpotTap")
            case .nearby(title: _):
                Mixpanel.mainInstance().track(event: "HomeScreenNearbySpotTap")
            }
        }
    }

    func openSpot(spot: MapSpot, postID: String?, commentID: String?) {
        let vc = SpotController(viewModel: SpotViewModel(serviceContainer: ServiceContainer.shared, spot: spot, passedPostID: postID, passedCommentID: commentID))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func forceRefresh() {
        Mixpanel.mainInstance().track(event: "HomeScreenPullToRefresh")
        HapticGenerator.shared.play(.soft)
        refresh.send(true)
        // using refresh indicator rather than activity so dont set isRefreshing here

        DispatchQueue.main.async {
            self.refreshControl.beginRefreshing()
        }
    }

    @objc func shareTap() {
        guard let url = URL(string: "https://apps.apple.com/app/id1477764252") else { return }
        let items = [url, "download sp0t 🫵‼️🔥"] as [Any]

        let activityView = UIActivityViewController(activityItems: items, applicationActivities: nil)
        self.present(activityView, animated: true)
        activityView.completionWithItemsHandler = { activityType, completed, _, _ in
            if completed {
                Mixpanel.mainInstance().track(event: "ProfileInviteSent", properties: ["type": activityType?.rawValue ?? ""])
            } else {
                Mixpanel.mainInstance().track(event: "ProfileInviteCancelled")
            }
        }
    }

    @objc func refreshTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenRefreshTap")
        HapticGenerator.shared.play(.soft)
        tapToRefresh = true
        isRefreshing = true
        refresh.send(true)
    }

    @objc func inboxTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenInboxTap")
        let vc = BotChatController(viewModel: BotChatViewModel(serviceContainer: ServiceContainer.shared))
        DispatchQueue.main.async {
            self.present(vc, animated: true)
        }
    }

    // called on view appear / when user updates location auth
    func refreshLocation() {
        isRefreshing = true
        refresh.send(true)
    }
}
