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
    typealias Input = AllPostsViewModel.Input
    typealias Output = AllPostsViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    
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
        collectionView.contentInsetAdjustmentBehavior = .always
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false

        // inset to show button view
        collectionView.register(MapPostImageCell.self, forCellWithReuseIdentifier: MapPostImageCell.reuseID)
        collectionView.register(MapPostVideoCell.self, forCellWithReuseIdentifier: MapPostVideoCell.reuseID)
        collectionView.delegate = self
        // collectionView.dataSource = self
        
        return collectionView
    }()
    
    private lazy var datasource: DataSource = {
        let datasource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .item(let post):
                if let videoURLString = post.videoURL,
                   let videoURL = URL(string: videoURLString),
                   let videoCell = collectionView.dequeueReusableCell(withReuseIdentifier: MapPostVideoCell.reuseID, for: indexPath) as? MapPostVideoCell {
                    videoCell.configure(post: post, url: videoURL)
                    videoCell.delegate = self
                    return videoCell
                    
                } else if let imageCell = collectionView.dequeueReusableCell(withReuseIdentifier: MapPostImageCell.reuseID, for: indexPath) as? MapPostImageCell {
                    imageCell.configure(post: post, row: indexPath.row)
                    imageCell.delegate = self
                    return imageCell
                }
                
                return nil
            }
        }
        
        return datasource
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
    private var likeAction = false
    
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
    
    private(set) var snapshot = Snapshot() {
        didSet {
            // TODO: Check this out!!!!
            // collectionView.reloadData()
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
        view.addSubview(collectionView)
        view.addSubview(activityIndicator)
        
        collectionView.refreshControl = refreshControl
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        activityIndicator.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.width.height.equalTo(50)
        }
        
        activityIndicator.startAnimating()
        
        edgesForExtendedLayout = [.top]
        
        let input = Input(refresh: refresh, limit: limit, lastFriendsItem: friendsLastItem, lastMapItem: lastItem)
        let output = viewModel.bind(to: input)
        
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)
                self?.snapshot = snapshot
                self?.likeAction = false
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
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
                    if !(self?.likeAction ?? false) {
                        self?.refresh.send(true)
                    }
                    
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
                    if !(self?.likeAction ?? false) {
                        self?.refresh.send(true)
                    }
                    
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
    
    func scrollToTop() {
        guard !snapshot.itemIdentifiers.isEmpty else {
            return
        }
        
        DispatchQueue.main.async {
            self.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
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
}

extension AllPostsViewController: ContentViewerDelegate {
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
        self.collectionView.scrollToItem(at: IndexPath(item: selectedPostIndex + increment, section: 0), at: .top, animated: true)
    }
    
    func likePost(postID: String) {
        likeAction = true
        HapticGenerator.shared.play(.light)
        viewModel.likePost(id: postID)
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

// MARK: UICollectionViewDelegate

extension AllPostsViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.frame.size
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        if (indexPath.row >= snapshot.numberOfItems - 7) && !isRefreshingPagination {
            isRefreshingPagination = true
            limit.send(15)
            friendsLastItem.send(viewModel.lastFriendsItem)
            lastItem.send(viewModel.lastMapItem)
            refresh.send(true)
        }
        
        if let cell = cell as? MapPostImageCell {
            cell.animateLocation()
            
        } else if let cell = cell as? MapPostVideoCell {
            loadVideoIfNeeded(for: cell, at: indexPath)
            cell.animateLocation()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let videoCell = cell as? MapPostVideoCell else {
            return
        }
        
        videoCell.playerView.player?.pause()
        videoCell.playerView.player = nil
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollView.contentInset.top = max((scrollView.frame.height - scrollView.contentSize.height) / 2, 0)
    }
    
    private func loadVideoIfNeeded(for videoCell: MapPostVideoCell, at indexPath: IndexPath) {
        guard videoCell.playerView.player == nil else {
            return
        }
        
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        
        switch item {
        case .item(let post):
            if let videoURLString = post.videoURL,
               let videoURL = URL(string: videoURLString) {
                videoCell.configureVideo(url: videoURL)
            }
        }
    }
}
