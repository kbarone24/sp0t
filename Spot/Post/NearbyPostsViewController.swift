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

protocol NearbyPostsDelegate: AnyObject {}

final class NearbyPostsViewController: UIViewController {
    typealias Input = NearbyPostsViewModel.Input
    typealias Output = NearbyPostsViewModel.Output
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
        tableView.register(ContentViewerCell.self, forCellReuseIdentifier: ContentViewerCell.reuseID)
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
            tableView.reloadData()
        }
    }
    
    internal let viewModel: NearbyPostsViewModel
    private var subscriptions = Set<AnyCancellable>()
    private(set) var refresh = PassthroughSubject<Bool, Never>()
    private let limit = PassthroughSubject<Int, Never>()
    private let lastItem = PassthroughSubject<DocumentSnapshot?, Never>()
    private var isRefreshingPagination = false
    
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
        
        let input = Input(refresh: refresh, limit: limit, lastItem: lastItem)
        let output = viewModel.bind(to: input)
        
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.snapshot = snapshot
                self?.activityIndicator.stopAnimating()
                self?.refreshControl.endRefreshing()
                self?.isRefreshingPagination = false
                
                if snapshot.itemIdentifiers.isEmpty {
                    self?.showEmptyAlert()
                }
            }
            .store(in: &subscriptions)
        
        refresh.send(true)
        limit.send(15)
        lastItem.send(nil)
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
    
    @objc private func forceRefresh() {
        refresh.send(true)
        lastItem.send(nil)
        refreshControl.beginRefreshing()
    }
    
    private func showEmptyAlert() {
        let alert = UIAlertController()
        alert.title = "Nothing to show"
        alert.message = "There are no nearby posts to you at this time. We are coming to your location"
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            alert.dismiss(animated: true)
        }
    }
    
    // called if table view or container view removal has begun
    func setCellOffsets(offset: Bool) {
        for cell in tableView.visibleCells {
            if let cell = cell as? ContentViewerCell {
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
    
    func tapToSelectedRow(increment: Int? = 0) {
        DispatchQueue.main.async {
            self.tableView.scrollToRow(at: IndexPath(row: self.selectedPostIndex + (increment ?? 0), section: 0), at: .top, animated: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            // set selected post index after main animation to avoid clogging main thread
            if let increment, increment != 0 { self?.selectedPostIndex += increment }
            if let cell = self?.tableView.cellForRow(at: IndexPath(row: self?.selectedPostIndex ?? 0, section: 0)) as? ContentViewerCell {
                cell.animateLocation()
            }
        }
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
            if let cell = self?.tableView.cellForRow(at: IndexPath(row: self?.selectedPostIndex ?? 0, section: 0)) as? ContentViewerCell {
                cell.animateLocation()
            }
        })
    }

    @objc func notifyImageChange(_ notification: NSNotification) {
        refresh.send(true)
    }

    func openComments(row: Int, animated: Bool) {
        if presentedViewController != nil { return }
        Mixpanel.mainInstance().track(event: "PostOpenComments")
        let item = snapshot.itemIdentifiers(inSection: .main)[row]
        switch item {
        case .item(let post):
            let commentsVC = CommentsController(commentsList: post.commentList, post: post)
            commentsVC.delegate = self
            present(commentsVC, animated: animated, completion: nil)
        }
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
}

// MARK: - ContentViewerDelegate

extension NearbyPostsViewController: ContentViewerDelegate {
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
            videoURL: "",
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

// MARK: - CommentsDelegate

extension NearbyPostsViewController: CommentsDelegate {
    func openProfileFromComments(user: UserProfile) {
        openProfile(user: user)
    }
}

// MARK: UITableViewDataSource and UITableViewDelegate

extension NearbyPostsViewController: UITableViewDataSource, UITableViewDelegate {
    
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ContentViewerCell.reuseID) as? ContentViewerCell else {
            return UITableViewCell()
        }
        
        cell.delegate = self
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        
        switch item {
        case .item(let post):
            if post.postVideo != nil || post.videoURL != nil || post.videoLocalPath != nil {
                cell.setUp(post: post, row: indexPath.row, mode: .video)
                
            } else {
                cell.setUp(post: post, row: indexPath.row, mode: .image)
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if (indexPath.row >= snapshot.numberOfItems - 10) && !isRefreshingPagination {
            isRefreshingPagination = true
            limit.send(15)
            lastItem.send(viewModel.lastItem)
        }
        
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        
        switch item {
        case .item(let post):
            Task {
                if let videoURL = post.videoURL {
                    viewModel.imageVideoService.downloadVideo(url: videoURL) { [weak self] url in
                        self?.setContentFor(indexPath: indexPath, videoURL: url, cell: cell)
                    }
                    
                } else {
                    let images = try? await viewModel.imageVideoService.downloadImages(
                        urls: post.imageURLs,
                        frameIndexes: post.frameIndexes,
                        aspectRatios: post.aspectRatios,
                        size: CGSize(
                            width: UIScreen.main.bounds.width * 2,
                            height: UIScreen.main.bounds.width * 2
                        )
                    )
                    
                    self.setContentFor(indexPath: indexPath, images: images ?? [], cell: cell)
                }
            }
        }
    }
    
    func setContentFor(
        indexPath: IndexPath,
        images: [UIImage] = [],
        videoURL: URL? = nil,
        cell: UITableViewCell
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard let cell = cell as? ContentViewerCell else {
                return
            }
            
            switch cell.mode {
            case .image:
                cell.setImages(images: images)
                
            case .video:
                cell.setVideo(url: videoURL)
            }
        }
    }
}
