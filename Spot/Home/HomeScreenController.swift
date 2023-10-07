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
    enum Section: Hashable {
        case main
    }

    enum Item: Hashable {
        case item(post: Post)
    }

    typealias Input = HomeScreenViewModel.Input
    typealias Output = HomeScreenViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    let viewModel: HomeScreenViewModel
    var subscriptions = Set<AnyCancellable>()

    let refresh = PassthroughSubject<Bool, Never>()
    let postListener = PassthroughSubject<(forced: Bool, commentInfo: (post: Post?, endDocument: DocumentSnapshot?)), Never>()
    let useEndDoc = PassthroughSubject<Bool, Never>()

    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            switch item {
            case .item(post: let post):
                let cell = tableView.dequeueReusableCell(withIdentifier: SpotPostCell.reuseID, for: indexPath) as? SpotPostCell
                cell?.configure(post: post, parent: .Home)
                cell?.delegate = self
                return cell
            }
        }
        return dataSource
    }()

    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = UIScreen.main.bounds.height / 2
        tableView.backgroundColor = SpotColors.HeaderGray.color
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        tableView.clipsToBounds = true
        tableView.allowsSelection = false
        tableView.automaticallyAdjustsScrollIndicatorInsets = true
        tableView.register(SpotPostCell.self, forCellReuseIdentifier: SpotPostCell.reuseID)
        return tableView
    }()

    private lazy var footerView: HomeScreenTableFooter = {
        let view = HomeScreenTableFooter()
        view.addButton.addTarget(self, action: #selector(addTap), for: .touchUpInside)
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
    private lazy var activityFooterView = ActivityFooterView()

    private var isRefreshingPagination = false {
        didSet {
            DispatchQueue.main.async {
                if self.isRefreshingPagination, !self.datasource.snapshot().itemIdentifiers.isEmpty {
                    self.activityFooterView.isHidden = false
                } else {
                    self.activityFooterView.isHidden = true
                }
            }
        }
    }

    private var tapToRefresh = false
    var scrollToPostID: String?

    private lazy var titleView: HomeScreenTitleView = {
        let view = HomeScreenTitleView()
        view.searchButton.addTarget(self, action: #selector(searchTap), for: .touchUpInside)
        view.profileButton.shadowButton.addTarget(self, action: #selector(profileButtonTap), for: .touchUpInside)
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

        tableView.refreshControl = refreshControl
        activityFooterView.isHidden = true
        tableView.tableFooterView = activityFooterView
        view.addSubview(tableView)

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
            $0.height.equalTo(100)
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
            refresh: refresh,
            postListener: postListener,
            useEndDoc: useEndDoc
        )

        let cachedOutput = viewModel.bindForCachedPosts(to: input)
        cachedOutput.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.tableView.invalidateIntrinsicContentSize()
                self?.refreshControl.endRefreshing()
                self?.activityIndicator.stopAnimating()
                self?.isRefreshingPagination = false
                self?.footerView.isHidden = false

                self?.datasource.apply(snapshot, animatingDifferences: false)
                self?.emptyState.isHidden = !snapshot.itemIdentifiers.isEmpty

                if let postID = self?.scrollToPostID, let selectedRow = self?.viewModel.getSelectedIndexFor(postID: postID) {
                    // scroll to selected row on post upload
                    let path = IndexPath(row: selectedRow, section: 0)
                    self?.tableView.scrollToRow(at: path, at: .middle, animated: true)
                    self?.scrollToPostID = nil
                }
            }
            .store(in: &subscriptions)


        let output = viewModel.bindForFetchedPosts(to: input)
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.tableView.invalidateIntrinsicContentSize()
                self?.refreshControl.endRefreshing()
                self?.activityIndicator.stopAnimating()
                self?.isRefreshingPagination = false
                self?.footerView.isHidden = false

                self?.datasource.apply(snapshot, animatingDifferences: false)

                if UserDataModel.shared.userInfo.flagged {
                    self?.addFlaggedState()
                }

                if snapshot.itemIdentifiers.isEmpty {
                    self?.addEmptyState()
                } else {
                    self?.emptyState.isHidden = true
                }
            }
            .store(in: &subscriptions)

        if viewModel.locationService.gotInitialLocation {
            // otherwise refresh sent by internal noti
            postListener.send((forced: false, commentInfo: (post: nil, endDocument: nil)))
            useEndDoc.send(true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "HomeScreenAppeared")

        if !datasource.snapshot().itemIdentifiers.isEmpty {
            postListener.send((forced: false, commentInfo: (post: nil, endDocument: nil)))
            useEndDoc.send(true)
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
        navigationController?.setUpOpaqueNav(backgroundColor: SpotColors.HeaderGray.color)
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
                    guard let self,
                          !completion.metadata.isFromCache
                    else { return }
                    DispatchQueue.main.async {
                        self.titleView.notificationsButton.pendingCount = completion.documents.count
                        self.navigationItem.titleView = self.titleView
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

    @objc func profileButtonTap() {
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
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // TODO: paginate if necessary
        let snapshot = datasource.snapshot()
        if (indexPath.row >= snapshot.numberOfItems - 2), !isRefreshingPagination, !viewModel.disablePagination {
            isRefreshingPagination = true

            postListener.send((forced: false, commentInfo: (post: nil, endDocument: nil)))
            useEndDoc.send(true)
        }

    }

    @objc func forceRefresh() {
        Mixpanel.mainInstance().track(event: "HomeScreenPullToRefresh")
        HapticGenerator.shared.play(.soft)
        postListener.send((forced: false, commentInfo: (post: nil, endDocument: nil)))
        useEndDoc.send(false)
        // using refresh indicator rather than activity so dont set isRefreshing here

        DispatchQueue.main.async {
            self.refreshControl.beginRefreshing()
        }
    }

    @objc func addTap() {
        let vc = CreatePostController(
            spot: nil,
            map: nil,
            parentPostID: nil,
            parentPosterID: nil,
            replyToID: nil,
            replyToUsername: nil,
            imageObject: nil,
            videoObject: nil)
        vc.delegate = self
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}


extension HomeScreenController: PostCellDelegate {
    func likePost(post: Post) {
        viewModel.likePost(post: post)
        refresh.send(false)
    }

    func unlikePost(post: Post) {
        viewModel.unlikePost(post: post)
        refresh.send(false)
    }

    func dislikePost(post: Post) {
        viewModel.dislikePost(post: post)
        refresh.send(false)
    }

    func undislikePost(post: Post) {
        viewModel.undislikePost(post: post)
        refresh.send(false)
    }

    func moreButtonTap(post: Post) {
        addPostActionSheet(post: post)
    }

    func viewMoreTap(parentPostID: String) {
        HapticGenerator.shared.play(.light)
        if let post = viewModel.presentedPosts.first(where: { $0.id == parentPostID }) {
            postListener.send((forced: true, commentInfo: (post: post, endDocument: post.lastCommentDocument)))
        }
    }

    func replyTap(spot: Spot?, parentPostID: String, parentPosterID: String, replyToID: String, replyToUsername: String) {
        // TODO: open create
        let vc = CreatePostController(
            spot: spot,
            map: nil,
            parentPostID: parentPostID,
            parentPosterID: parentPosterID,
            replyToID: replyToID,
            replyToUsername: replyToUsername,
            imageObject: nil,
            videoObject: nil)
        vc.delegate = self
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func spotTap(post: Post) {
        if let postID = post.id, let spotID = post.spotID, let spotName = post.spotName {
            let spot = Spot(id: spotID, spotName: spotName)
            openSpot(spot: spot, postID: postID, commentID: nil)
        }
    }

    func openSpot(spot: Spot, postID: String?, commentID: String?) {
        let vc = SpotController(viewModel: SpotViewModel(serviceContainer: ServiceContainer.shared, spot: spot, passedPostID: postID, passedCommentID: commentID))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }


    func mapTap(post: Post) {
        if let mapID = post.mapID, let mapName = post.mapName {
            let map = CustomMap(id: mapID, mapName: mapName)
            openMap(map: map, postID: nil, commentID: nil)
        }
    }

    func openMap(map: CustomMap, postID: String?, commentID: String?) {
        let vc = CustomMapController(viewModel: CustomMapViewModel(serviceContainer: ServiceContainer.shared, map: map, passedPostID: postID, passedCommentID: commentID))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func profileTap(userInfo: UserProfile) {
        let vc = ProfileViewController(viewModel: ProfileViewModel(serviceContainer: ServiceContainer.shared, profile: userInfo))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension HomeScreenController: CreatePostDelegate {
    func finishUpload(post: Post) {
        viewModel.addNewPost(post: post)
        self.scrollToPostID = post.id ?? ""
        self.refresh.send(false)
    }
}
