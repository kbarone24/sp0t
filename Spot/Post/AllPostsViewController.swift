//
//  AllPostsViewController.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import Combine
import Mixpanel
import Firebase

final class AllPostsViewController: UIViewController {
    
    typealias Input = AllPostsViewModel.Input
    typealias Output = AllPostsViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    enum Section: Hashable {
        case main
    }
    
    enum Item: Hashable {
        case item(post: MapPost)
    }
    
    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIScreen.main.bounds.height, right: 0)
        tableView.backgroundColor = .black
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = true
        tableView.showsVerticalScrollIndicator = false
        tableView.scrollsToTop = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.shouldIgnoreContentInsetAdjustment = true
        // inset to show button view
        tableView.register(MapPostImageCell.self, forCellReuseIdentifier: MapPostImageCell.reuseID)
        tableView.register(MapPostVideoCell.self, forCellReuseIdentifier: MapPostVideoCell.reuseID)
        tableView.sectionHeaderTopPadding = 0.0
        tableView.delegate = self
        tableView.dataSource = self
        
        return tableView
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
        return refreshControl
    }()
    
    private lazy var activityIndicator: CustomActivityIndicator = {
        let activityIndictor = CustomActivityIndicator()
        activityIndictor.startAnimating()
        return activityIndictor
    }()
    
    lazy var deleteIndicator = CustomActivityIndicator()
    
    var selectedPostIndex = 0 {
        didSet {
            guard !snapshot.itemIdentifiers.isEmpty else {
                return
            }
            
            let item = snapshot.itemIdentifiers(inSection: .main)[selectedPostIndex]
            switch item {
            case .item(let post):
                viewModel.updatePostIndex(post: post)
            }
        }
    }
    
    var rowHeight: CGFloat {
        return tableView.bounds.height - 0.01
    }
    
    var currentRowContentOffset: CGFloat {
        return rowHeight * CGFloat(selectedPostIndex)
    }
    
    var maxRowContentOffset: CGFloat {
        return rowHeight * CGFloat(snapshot.numberOfItems - 1)
    }
    
    var tableViewOffset = false {
        didSet {
            DispatchQueue.main.async {
                self.setCellOffsets(offset: self.tableViewOffset)
            }
        }
    }
    
    private(set) var snapshot = Snapshot() {
        didSet {
            tableView.reloadData()
        }
    }
    
    internal let viewModel: AllPostsViewModel
    var openComments = false
    private var subscriptions = Set<AnyCancellable>()
    private(set) var refresh = PassthroughSubject<Bool, Never>()
    private let limit = PassthroughSubject<Int, Never>()
    private let lastItem = PassthroughSubject<DocumentSnapshot?, Never>()
    private let friendsLastItem = PassthroughSubject<DocumentSnapshot?, Never>()
    private var isRefreshingPagination = false
    
    init(viewModel: AllPostsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        view.addSubview(activityIndicator)
        
        tableView.refreshControl = refreshControl
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        activityIndicator.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.width.height.equalTo(50)
        }
        
        activityIndicator.startAnimating()
        
        edgesForExtendedLayout = [.top]
        addNotifications()
        
        let input = Input(refresh: refresh, limit: limit, lastFriendsItem: friendsLastItem, lastMapItem: lastItem)
        let output = viewModel.bind(to: input)
        
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.snapshot = snapshot
                self?.isRefreshingPagination = false
                self?.activityIndicator.stopAnimating()
                self?.refreshControl.endRefreshing()
            }
            .store(in: &subscriptions)
        
        refresh.send(true)
        limit.send(15)
        lastItem.send(nil)
        friendsLastItem.send(nil)
        
        subscribeToFriendsListener()
        subscribeToMapListener()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PostPageOpen")
        
        if openComments {
            openComments(row: selectedPostIndex, animated: true)
            openComments = false
        }
    }
    
    private func subscribeToFriendsListener() {
        let request = Firestore.firestore()
            .collection(FirebaseCollectionNames.posts.rawValue)
            .limit(to: 15)
            .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
        
        let friendsQuery = request.whereField(FirebaseCollectionFields.friendsList.rawValue, arrayContains: UserDataModel.shared.uid)
        
        if let lastFriendsItem = viewModel.lastFriendsItem {
            friendsQuery.start(afterDocument: lastFriendsItem)
        }
        
        friendsQuery.snapshotPublisher()
            .removeDuplicates()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    self?.refresh.send(true)
                    if self?.snapshot.numberOfItems ?? 0 <= 0 {
                        self?.limit.send(15)
                    } else {
                        self?.limit.send(self?.snapshot.numberOfItems ?? 15)
                    }
                })
            .store(in: &subscriptions)
    }
    
    private func subscribeToMapListener() {
        let request = Firestore.firestore()
            .collection(FirebaseCollectionNames.posts.rawValue)
            .limit(to: 15)
            .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
        
        let mapsQuery = request.whereField(FirebaseCollectionFields.inviteList.rawValue, arrayContains: UserDataModel.shared.uid)
        
        if let lastMapItem = viewModel.lastMapItem {
            mapsQuery.start(afterDocument: lastMapItem)
        }
        
        mapsQuery.snapshotPublisher()
            .removeDuplicates()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    self?.refresh.send(true)
                    if self?.snapshot.numberOfItems ?? 0 <= 0 {
                        self?.limit.send(15)
                    } else {
                        self?.limit.send(self?.snapshot.numberOfItems ?? 15)
                    }
                })
            .store(in: &subscriptions)
    }
    
    @objc private func forceRefresh() {
        refresh.send(true)
        lastItem.send(nil)
        friendsLastItem.send(nil)
        refreshControl.beginRefreshing()
    }
    
    func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyImageChange(_:)), name: NSNotification.Name("PostImageChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name(("NewPost")), object: nil)
    }
    
    func scrollToTop() {
        guard !snapshot.itemIdentifiers.isEmpty else {
            return
        }
        
        DispatchQueue.main.async {
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
        
        selectedPostIndex = 0
    }
    
    func openComments(row: Int, animated: Bool) {
        Mixpanel.mainInstance().track(event: "PostOpenComments")
        let item = snapshot.itemIdentifiers(inSection: .main)[selectedPostIndex]
        switch item {
        case .item(let post):
            let commentsVC = CommentsController(commentsList: post.commentList, post: post)
            commentsVC.delegate = self
            DispatchQueue.main.async {
                self.present(commentsVC, animated: animated, completion: nil)
            }
        }
    }
    
    @objc func notifyImageChange(_ notification: NSNotification) {
        refresh.send(true)
    }
    
    @objc func notifyNewPost(_ notification: NSNotification) {
        refresh.send(true)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let velocity = scrollView.panGestureRecognizer.velocity(in: view)
        let translation = scrollView.panGestureRecognizer.translation(in: view)
        let composite = translation.y + velocity.y / 4
        
        let rowHeight = tableView.bounds.height
        if composite < -(rowHeight / 4) && selectedPostIndex < snapshot.numberOfItems - 1 {
            selectedPostIndex += 1
        } else if composite > rowHeight / 4 && selectedPostIndex != 0 {
            selectedPostIndex -= 1
        }
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y - 1), animated: true)
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y + 1), animated: true)
        scrollToSelectedRow(animated: true)
    }
    
    func scrollToSelectedRow(animated: Bool) {
        var duration: TimeInterval = 0.15
        if animated {
            let offset = abs(currentRowContentOffset - tableView.contentOffset.y)
            duration = max(TimeInterval(0.25 * offset / tableView.bounds.height), 0.15)
        }
        
        UIView.transition(with: tableView, duration: duration, options: [.beginFromCurrentState, .curveEaseOut], animations: {
            self.tableView.setContentOffset(CGPoint(x: 0, y: CGFloat(self.currentRowContentOffset)), animated: false)
            self.tableView.layoutIfNeeded()
            
        }, completion: { [weak self] _ in
            self?.tableViewOffset = false
            if let cell = self?.tableView.cellForRow(at: IndexPath(row: self?.selectedPostIndex ?? 0, section: 0)) as? MapPostImageCell {
                cell.animateLocation()
            }
        })
    }
}

extension AllPostsViewController: ContentViewerDelegate {
    // called if table view or container view removal has begun
    func setCellOffsets(offset: Bool) {
        for cell in tableView.visibleCells {
            if let cell = cell as? MapPostImageCell {
                cell.cellOffset = tableViewOffset
            }
        }
    }
    
    func tapToNextPost() {
        if selectedPostIndex < snapshot.numberOfItems - 1 {
            tapToSelectedRow(increment: 1)
        }
    }
    
    func tapToPreviousPost() {
        if selectedPostIndex > 0 {
            tapToSelectedRow(increment: -1)
        }
    }
    
    func tapToSelectedRow(increment: Int = 0) {
        tableView.scrollToRow(at: IndexPath(row: selectedPostIndex + increment, section: 0), at: .top, animated: true)
    }
    
    func likePost(postID: String) {
        HapticGenerator.shared.play(.light)
        let allPosts = snapshot.itemIdentifiers.map { item in
            switch item {
            case .item(let post):
                return post
            }
        }
        
        let post = allPosts.first(where: { $0.id == postID })
        
        if allPosts[selectedPostIndex].likers.firstIndex(where: { $0 == UserDataModel.shared.uid }) != nil {
            Mixpanel.mainInstance().track(event: "PostPageUnlikePost")
            viewModel.unlikePost(post: post)
        } else {
            Mixpanel.mainInstance().track(event: "PostPageLikePost")
            viewModel.likePost(post: post)
        }
        
        refresh.send(false)
    }
    
    func openPostComments() {
        openComments(row: selectedPostIndex, animated: true)
    }
    
    func openPostActionSheet() {
        Mixpanel.mainInstance().track(event: "PostPageElipsesTap")
        addActionSheet()
    }
    
    func getSelectedPostIndex() -> Int {
        return selectedPostIndex
    }
    
    func openProfile(user: UserProfile) {
        let profileVC = ProfileViewController(userProfile: user)
        DispatchQueue.main.async { self.navigationController?.pushViewController(profileVC, animated: true) }
    }
    
    func openMap(mapID: String, mapName: String) {
        var map = CustomMap(
            founderID: "",
            imageURL: "",
            likers: [],
            mapName: mapName,
            memberIDs: [],
            posterIDs: [],
            posterUsernames: [],
            postIDs: [],
            postImageURLs: [],
            secret: false,
            spotIDs: []
        )
        
        map.id = mapID
        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: [])
        navigationController?.pushViewController(customMapVC, animated: true)
    }
    
    func openSpot(post: MapPost) {
        let spotVC = SpotPageController(mapPost: post)
        navigationController?.pushViewController(spotVC, animated: true)
    }
}

extension AllPostsViewController: CommentsDelegate {
    func openProfileFromComments(user: UserProfile) {
        openProfile(user: user)
    }
}

// MARK: UITableViewDataSource and UITableViewDelegate

extension AllPostsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard !snapshot.sectionIdentifiers.isEmpty else {
            return 0
        }
        
        let section = snapshot.sectionIdentifiers[section]
        return snapshot.numberOfItems(inSection: section)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return max(0.01, tableView.bounds.height - 0.01)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        
        switch item {
        case .item(let post):
            if let videoURLString = post.videoURL,
               let videoURL = URL(string: videoURLString),
               let videoCell = tableView.dequeueReusableCell(withIdentifier: MapPostVideoCell.reuseID, for: indexPath) as? MapPostVideoCell {
                videoCell.configure(post: post, url: videoURL)
                videoCell.delegate = self
                return videoCell
                
            } else if let imageCell = tableView.dequeueReusableCell(withIdentifier: MapPostImageCell.reuseID, for: indexPath) as? MapPostImageCell {
                imageCell.configure(post: post, row: indexPath.row)
                imageCell.delegate = self
                return imageCell
            } else {
                return UITableViewCell()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if (indexPath.row >= snapshot.numberOfItems - 7) && !isRefreshingPagination {
            isRefreshingPagination = true
            limit.send(15)
            friendsLastItem.send(viewModel.lastFriendsItem)
            lastItem.send(viewModel.lastMapItem)
        }
        
        if let cell = cell as? MapPostImageCell {
            cell.animateLocation()
        } else if let cell = cell as? MapPostVideoCell {
            cell.playerView.player?.play()
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let videoCell = cell as? MapPostVideoCell else {
            return
        }
        
        videoCell.playerView.player?.pause()
    }
}
