//
//  NearbyPostsViewController.swift
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

final class NearbyPostsViewController: UIViewController {
    typealias Input = NearbyPostsViewModel.Input
    typealias Output = NearbyPostsViewModel.Output
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
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.isScrollEnabled = true
        collectionView.isPagingEnabled = true
        collectionView.automaticallyAdjustsScrollIndicatorInsets = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false

        collectionView.register(MapPostImageCell.self, forCellWithReuseIdentifier: MapPostImageCell.reuseID)
        collectionView.register(MapPostVideoCell.self, forCellWithReuseIdentifier: MapPostVideoCell.reuseID)
        collectionView.delegate = self
        // collectionView.dataSource = self
        
        return collectionView
    }()
    
    private(set) lazy var datasource: DataSource = {
        let datasource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .item(let post):
                if let videoURLString = post.videoURL,
                   let videoURL = URL(string: videoURLString),
                   let videoCell = collectionView.dequeueReusableCell(withReuseIdentifier: MapPostVideoCell.reuseID, for: indexPath) as? MapPostVideoCell {
                    videoCell.configure(post: post, parent: .Nearby, url: videoURL)
                    videoCell.delegate = self
                    return videoCell
                    
                } else if let imageCell = collectionView.dequeueReusableCell(withReuseIdentifier: MapPostImageCell.reuseID, for: indexPath) as? MapPostImageCell {
                    imageCell.configure(post: post, parent: .Nearby, row: indexPath.row)
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
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let activityIndictor = UIActivityIndicatorView()
        activityIndictor.startAnimating()
        return activityIndictor
    }()

    private lazy var emptyState = NearbyPostsEmptyState()
    
    lazy var deleteIndicator = UIActivityIndicatorView()
    private var likeAction = false

    internal let viewModel: NearbyPostsViewModel
    private var subscriptions = Set<AnyCancellable>()
    private(set) var refresh = PassthroughSubject<Bool, Never>()
    private let limit = PassthroughSubject<Int, Never>()
    private let lastItem = PassthroughSubject<DocumentSnapshot?, Never>()
    private var isRefreshingPagination = false
    var isSelectedViewController = false
    
    init(viewModel: NearbyPostsViewModel) {
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
        view.addSubview(emptyState)
        view.addSubview(activityIndicator)

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
        
        edgesForExtendedLayout = [.top]
        
        let input = Input(refresh: refresh, limit: limit, lastItem: lastItem)
        let output = viewModel.bind(to: input)
        
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)
                self?.isRefreshingPagination = false
                self?.activityIndicator.stopAnimating()
                self?.refreshControl.endRefreshing()
                if snapshot.itemIdentifiers.isEmpty {
                    self?.addEmptyState()
                } else {
                    self?.emptyState.isHidden = true
                }
            }
            .store(in: &subscriptions)
        
        refresh.send(true)
        limit.send(50)
        lastItem.send(nil)
        
        subscribeToNotifications()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PostPageOpen")

        playVideosOnViewAppear()
        NotificationCenter.default.addObserver(self, selector: #selector(playVideosOnViewAppear), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for cell in collectionView.visibleCells {
            if let cell = cell as? MapPostVideoCell {
                cell.pauseOnEndDisplaying()
            }
        }

        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        likeAction = false
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    @objc private func forceRefresh() {
        refresh.send(true)
        lastItem.send(nil)
        refreshControl.beginRefreshing()
    }
    
    private func subscribeToNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(postChanged(_:)), name: NSNotification.Name("PostChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deletePost(_:)), name: NSNotification.Name("DeletePost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(locationChanged), name: NSNotification.Name("UpdatedLocationAuth"), object: nil)
    }
    
    func scrollToTop() {
        let snapshot = datasource.snapshot()
        guard !snapshot.itemIdentifiers.isEmpty else {
            return
        }
        
        DispatchQueue.main.async {
            self.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
        }
    }
    
    func openComments(post: MapPost, animated: Bool) {
        Mixpanel.mainInstance().track(event: "PostOpenComments")
        let commentsVC = CommentsController(commentsList: post.commentList, post: post)
        commentsVC.delegate = self
        DispatchQueue.main.async {
            self.present(commentsVC, animated: animated, completion: nil)
        }
    }

    private func addEmptyState() {
        emptyState.isHidden = false
        guard let locationService = try? ServiceContainer.shared.service(for: \.locationService) else { return }
        if locationService.currentLocationStatus() != .authorizedWhenInUse && locationService.currentLocationStatus() != .notDetermined {
            emptyState.configureNoAccess()
        } else {
            emptyState.configureNoPosts()
        }
    }

    @objc func playVideosOnViewAppear() {
        for cell in collectionView.visibleCells {
            if let cell = cell as? MapPostVideoCell {
                cell.playOnDidDisplay()
            }
        }
    }
}

extension NearbyPostsViewController: ContentViewerDelegate {
    func likePost(postID: String) {
        likeAction = true
        HapticGenerator.shared.play(.light)
        viewModel.likePost(id: postID)
     //   refresh.send(false)
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
}

extension NearbyPostsViewController: CommentsDelegate {
    func openProfileFromComments(user: UserProfile) {
        openProfile(user: user)
    }
}

// MARK: UICollectionViewDelegate

extension NearbyPostsViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.frame.size
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let snapshot = datasource.snapshot()
        if (indexPath.row >= snapshot.numberOfItems - 7) && !isRefreshingPagination {
            isRefreshingPagination = true
            refresh.send(true)
            limit.send(25)
            lastItem.send(viewModel.lastItem)
        }
        
        if let cell = cell as? MapPostImageCell {
            cell.animateLocation()
            
        } else if let cell = cell as? MapPostVideoCell {
            loadVideoIfNeeded(for: cell, at: indexPath)
            cell.animateLocation()
            cell.addNotifications()
        }

        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        switch item {
        case .item(let post):
            viewModel.updatePostIndex(post: post)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // sync snapshot with view model when post scrolls off screen
        if likeAction {
            refresh.send(false)
            likeAction = false
        }

        if let videoCell = cell as? MapPostVideoCell {
            videoCell.pauseOnEndDisplaying()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollView.contentInset.top = max((scrollView.frame.height - scrollView.contentSize.height) / 2, 0)
    }
    
    private func loadVideoIfNeeded(for videoCell: MapPostVideoCell, at indexPath: IndexPath) {
        guard videoCell.playerView.player == nil else {
            videoCell.playOnDidDisplay()
            return
        }
        
        let snapshot = datasource.snapshot()
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
    
    @objc private func postChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
              let post = userInfo["post"] as? MapPost,
              let like = userInfo["like"] as? Bool,
              (!like || !isSelectedViewController) else {
            return
        }
        // send refresh on comment update only, unless this isnt the active vc
        viewModel.updatePost(id: post.id, update: post)
        refresh.send(false)
    }

    @objc func deletePost(_ notification: Notification) {
        guard let post = notification.userInfo?["post"] as? MapPost, let postID = post.id else { return }
        viewModel.deletePost(id: postID)
        refresh.send(false)
    }

    @objc func locationChanged() {
        DispatchQueue.main.async { self.activityIndicator.startAnimating() }
        emptyState.isHidden = true
        refresh.send(true)
    }
}
