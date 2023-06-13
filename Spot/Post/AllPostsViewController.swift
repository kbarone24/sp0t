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
import FirebaseFirestore

final class AllPostsViewController: UIViewController {
    var viewDidLoadCalled = false
    typealias Input = AllPostsViewModel.Input
    typealias Output = AllPostsViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    
    let cache = VIResourceLoaderManager()
    
    enum Section: Hashable {
        case main
    }
    
    enum Item: Hashable {
        case item(post: MapPost)
    }
    
    private(set) lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.sectionInsetReference = .fromContentInset
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.isScrollEnabled = true
        collectionView.isPagingEnabled = true
        collectionView.automaticallyAdjustsScrollIndicatorInsets = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false

        // inset to show button view
        collectionView.register(MapPostImageCell.self, forCellWithReuseIdentifier: MapPostImageCell.reuseID)
        collectionView.register(MapPostVideoCell.self, forCellWithReuseIdentifier: MapPostVideoCell.reuseID)
        collectionView.register(EmptyCollectionCell.self, forCellWithReuseIdentifier: EmptyCollectionCell.reuseID)
        collectionView.delegate = self

        return collectionView
    }()
    
    private(set) lazy var datasource: DataSource = {
        let datasource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .item(let post):
                if let videoURLString = post.videoURL,
                   let videoURL = URL(string: videoURLString),
                   let videoCell = collectionView.dequeueReusableCell(withReuseIdentifier: MapPostVideoCell.reuseID, for: indexPath) as? MapPostVideoCell {
                    let playerItem = self.isScrollingToTop ? nil : self.cache.playerItem(with: videoURL)
                    videoCell.configure(post: post, parent: .AllPosts, playerItem: playerItem)
                    videoCell.delegate = self
                    return videoCell

                } else if let imageCell = collectionView.dequeueReusableCell(withReuseIdentifier: MapPostImageCell.reuseID, for: indexPath) as? MapPostImageCell {
                    imageCell.configure(post: post, parent: .AllPosts, row: indexPath.row)
                    imageCell.delegate = self
                    return imageCell
                }
                
                return nil
            }
        }
        
        return datasource
    }()
    
    private(set) lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
        return refreshControl
    }()
    
    private(set) lazy var activityIndicator: UIActivityIndicatorView = {
        let activityIndictor = UIActivityIndicatorView()
        activityIndictor.startAnimating()
        return activityIndictor
    }()

    private lazy var addMapConfirmationView = AddMapConfirmationView()

    private var showEmptyState = false
    private(set) lazy var emptyState = MyWorldEmptyState()
    
    lazy var deleteIndicator = UIActivityIndicatorView()
    private var likeAction = false
        
    internal let viewModel: AllPostsViewModel
    private var subscriptions = Set<AnyCancellable>()
    private(set) var refresh = PassthroughSubject<Bool, Never>()
    private let friendsLastItem = PassthroughSubject<DocumentSnapshot?, Never>()
    private let lastFriendsItemListener = PassthroughSubject<Bool, Never>()
    private(set) var changedDocumentIDs = PassthroughSubject<[String], Never>()
    private var subscribedToListeners = false
    var isSelectedViewController = false
    private var isScrollingToTop = false
    private var isDragging = false

    private var isRefreshingPagination = false {
        didSet {
            DispatchQueue.main.async {
                if self.isRefreshingPagination, !self.datasource.snapshot().itemIdentifiers.isEmpty {
                    self.collectionView.layoutIfNeeded()
                    let collectionBottom = self.collectionView.contentSize.height
                    self.activityIndicator.snp.removeConstraints()
                    self.activityIndicator.snp.makeConstraints {
                        $0.centerX.equalToSuperview()
                        $0.width.height.equalTo(30)
                        $0.top.equalTo(collectionBottom + 15)
                    }
                    self.activityIndicator.startAnimating()
                }
            }
        }
    }

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
        // patch fix for viewDidLoad being called twice
        if viewDidLoadCalled { return }
        viewDidLoadCalled = true
        view.addSubview(collectionView)
        view.addSubview(emptyState)
        collectionView.addSubview(activityIndicator)
        
        collectionView.refreshControl = refreshControl
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        emptyState.isHidden = true
        emptyState.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        activityIndicator.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.width.height.equalTo(50)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.startAnimating()

        addMapConfirmationView.isHidden = true
        view.addSubview(addMapConfirmationView)
        addMapConfirmationView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(34)
            $0.height.equalTo(57)
            $0.bottom.equalTo(-23)
        }
        
        edgesForExtendedLayout = [.top]
        
        let input = Input(
            refresh: refresh,
            lastFriendsItemListener: lastFriendsItemListener,
            lastFriendsItem: friendsLastItem
        )
        
        let output = viewModel.bind(to: input)
        
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)
                if self?.isRefreshingPagination ?? false && self?.isDragging ?? false {
                    self?.collectionView.scrollToNextRowInFeed()
                }

                self?.isRefreshingPagination = false
                self?.activityIndicator.stopAnimating()
                self?.refreshControl.endRefreshing()

                if snapshot.itemIdentifiers.isEmpty {
                    self?.emptyState.isHidden = false
                    self?.showEmptyState = true
                } else {
                    self?.emptyState.isHidden = true
                    self?.showEmptyState = false
                }
            }
            .store(in: &subscriptions)
        
        refresh.send(true)
        friendsLastItem.send(nil)
        lastFriendsItemListener.send(false)

        subscribeToNotifications()
        subscribeToFriendsListener()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "AllPostsOpen")

        playVideosForVisibleCells()
        NotificationCenter.default.addObserver(self, selector: #selector(allPostsEnteredForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for cell in collectionView.visibleCells {
            if let cell = cell as? MapPostVideoCell {
                cell.removeVideo()
            }
        }

        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        likeAction = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    private func subscribeToNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(postChanged(_:)), name: NSNotification.Name("PostChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deletePost(_:)), name: NSNotification.Name("DeletePost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(postOpen(_:)), name: NSNotification.Name("PostOpen"), object: nil)
    }
    
    private func subscribeToFriendsListener() {
        subscribedToListeners = true
        // only listening for changes on most recent posts for now
        let request = Firestore.firestore()
            .collection(FirebaseCollectionNames.posts.rawValue)
            .limit(to: 15)
            .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
        
        let friendsQuery = request.whereField(FirebaseCollectionFields.friendsList.rawValue, arrayContains: UserDataModel.shared.uid)
        
        if let lastFriendsItem = viewModel.lastFriendsItem {
            friendsQuery.start(afterDocument: lastFriendsItem)
        }

        friendsQuery.snapshotPublisher(includeMetadataChanges: true)
            .removeDuplicates()
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] completion in
                    guard let self,
                          !completion.metadata.isFromCache,
                          !completion.documentChanges.isEmpty,
                          !self.likeAction,
                          (showEmptyState || !self.datasource.snapshot().itemIdentifiers.isEmpty)
                    else { return }

                    viewModel.addedPostIDs = completion.documentChanges.filter({ $0.type == .added }).map({ $0.document.documentID })
                    viewModel.removedPostIDs = completion.documentChanges.filter({ $0.type == .removed }).map({ $0.document.documentID })
                    viewModel.modifiedPostIDs = completion.documentChanges.filter({ $0.type == .modified }).map({ $0.document.documentID })

                    // block seenList and other unnecessary updates
                    if viewModel.addedPostIDs.isEmpty, viewModel.removedPostIDs.isEmpty {
                        guard checkIfShouldUpdate(documents: completion.documents) else {
                            return
                        }
                    }

                    self.refresh.send(true)
                    self.lastFriendsItemListener.send(true)
                })
            .store(in: &subscriptions)
    }

    @objc private func forceRefresh() {
        refresh.send(true)
        friendsLastItem.send(nil)

        refreshControl.beginRefreshing()
    }
    
    func scrollToTop() {
        let snapshot = datasource.snapshot()
        guard !snapshot.itemIdentifiers.isEmpty else {
            return
        }

        isScrollingToTop = true
        DispatchQueue.main.async {
            self.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isScrollingToTop = false
                self?.playVideosForVisibleCells()
            }
        }
    }

    @objc func allPostsEnteredForeground() {
        playVideosForVisibleCells()
    }
    
    func openComments(post: MapPost, animated: Bool) {
        let commentsVC = CommentsController(commentsList: post.commentList, post: post)
        commentsVC.delegate = self
        DispatchQueue.main.async {
            self.present(commentsVC, animated: animated, completion: nil)
        }
        Mixpanel.mainInstance().track(event: "PostOpenComments")
    }

    private func checkIfShouldUpdate(documents: [QueryDocumentSnapshot]) -> Bool {
        guard !likeAction else { return false }
        for doc in documents {
            let post = try? doc.data(as: MapPost.self)
            if let post, let cachedPost = viewModel.presentedPosts[id: post.id ?? ""] {
                if post.likers.count != cachedPost.likers.count || post.commentCount != cachedPost.commentCount {
                    return true
                }
            }
        }
        return false
    }
}

extension AllPostsViewController: ContentViewerDelegate {
    func likePost(postID: String) {
        likeAction = true
        HapticGenerator.shared.play(.light)
        viewModel.likePost(id: postID)
        // refresh.send(false)
        // refresh will send on post changed noti
    }
    
    func openPostComments(post: MapPost) {
        openComments(post: post, animated: true)
    }
    
    func openPostActionSheet(post: MapPost) {
        Mixpanel.mainInstance().track(event: "PostPageElipsesTap")
        addActionSheet(post: post)
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

    func joinMap(mapID: String) {
        // join map
        Mixpanel.mainInstance().track(event: "MyPostsJoinTap")
        toggleAddMapView()
        viewModel.joinMap(mapID: mapID)
    }

    private func toggleAddMapView() {
        addMapConfirmationView.isHidden = false
        addMapConfirmationView.alpha = 1.0
        UIView.animate(withDuration: 0.3, delay: 2.0, animations: { [weak self] in
            self?.addMapConfirmationView.alpha = 0.0
        }, completion: { [weak self] _ in
            self?.addMapConfirmationView.isHidden = true
            self?.addMapConfirmationView.alpha = 1.0
        })
    }
}

extension AllPostsViewController: CommentsDelegate {
    func openProfileFromComments(user: UserProfile) {
        openProfile(user: user)
    }
}

// MARK: UICollectionViewDelegate

extension AllPostsViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.frame.size
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? MapPostImageCell {
            cell.animateLocation()
            
        } else if let cell = cell as? MapPostVideoCell {
            cell.animateLocation()
            loadVideoIfNeeded(for: cell, at: indexPath)
        }

        let snapshot = datasource.snapshot()
        if (indexPath.row >= snapshot.numberOfItems - 5) && !isRefreshingPagination, !viewModel.disablePagination {
            isRefreshingPagination = true
            refresh.send(true)
            friendsLastItem.send(viewModel.lastFriendsItem)
            lastFriendsItemListener.send(false)
        }

        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        switch item {
        case .item(let post):
            viewModel.updatePostIndex(post: post)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? MapPostVideoCell {
            cell.removeVideo()
            cell.locationView.stopAnimating()
        } else if let cell = cell as? MapPostImageCell {
            cell.locationView.stopAnimating()
        }

        // sync snapshot with view model when post scrolls off screen
        if likeAction {
            refresh.send(false)
            likeAction = false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // send notification to disable zoom
        NotificationCenter.default.post(Notification(name: Notification.Name("FeedBeganDragging")))
        isDragging = true
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollView.contentInset.top = max((scrollView.frame.height - scrollView.contentSize.height) / 2, 0)
        NotificationCenter.default.post(Notification(name: Notification.Name("FeedEndDragging")))
        isDragging = false
    }

    private func playVideosForVisibleCells() {
        for i in 0..<collectionView.visibleCells.count {
            if let cell = collectionView.visibleCells[i] as? MapPostVideoCell {
                loadVideoIfNeeded(for: cell, at: collectionView.indexPathsForVisibleItems[i])
            }
        }
    }

    private func loadVideoIfNeeded(for videoCell: MapPostVideoCell, at indexPath: IndexPath) {
        guard isSelectedViewController, !isScrollingToTop else { return }
        guard videoCell.playerView.player == nil else {
            videoCell.playVideo()
            return
        }
        
        let snapshot = datasource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        
        switch item {
        case .item(let post):
            if let videoURLString = post.videoURL,
               let videoURL = URL(string: videoURLString),
               let playerItem = self.cache.playerItem(with: videoURL) {
                videoCell.configureVideo(playerItem: playerItem, playImmediately: true)
            }
        }
    }
    
    @objc private func postChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
              let post = userInfo["post"] as? MapPost,
              let like = userInfo["like"] as? Bool,
              (!like || !isSelectedViewController) else {
            return
        }
        // send refresh on comment update only
        viewModel.updatePost(id: post.id, update: post)
        refresh.send(false)
    }

    @objc func deletePost(_ notification: Notification) {
        guard let post = notification.userInfo?["post"] as? MapPost, let postID = post.id else { return }
        viewModel.deletePost(id: postID)
        refresh.send(false)
    }

    @objc func postOpen(_ notification: Notification) {
        guard let post = notification.userInfo?["post"] as? MapPost, let id = post.id, viewModel.presentedPosts[id: id] != nil else { return }
        // added separate object here + moved to main thread to avoid illegal memory access
        DispatchQueue.main.async {
            self.viewModel.presentedPosts[id: id]?.seenList?.append(UserDataModel.shared.uid)
            self.viewModel.presentedPosts[id: id]?.seenList?.removeDuplicates()
            if !self.viewModel.presentedPosts.elements.contains(where: { !$0.seen }) {
                NotificationCenter.default.post(Notification(name: NSNotification.Name(rawValue: "SeenMyPosts")))
            }
        }
    }
}
