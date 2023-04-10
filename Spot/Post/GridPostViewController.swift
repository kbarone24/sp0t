//
//  GridPostViewController.swift
//  Spot
//
//  Created by Kenny Barone on 3/16/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import Mixpanel
import IdentifiedCollections

protocol PostControllerDelegate: AnyObject {
    func indexChanged(rowsRemaining: Int)
}

final class GridPostViewController: UIViewController {
    var parentVC: PostParent
    var postsLoaded: Bool
    var postsList: IdentifiedArrayOf<MapPost> = []
    weak var delegate: PostControllerDelegate?
    var openComments = false

    lazy var postService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()

    lazy var mapService: MapServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapsService)
        return service
    }()

    lazy var spotService: SpotServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.spotService)
        return service
    }()


    // Explore maps fetch
    var startingIndex = 0
    var exploreMapsEndDocument: DocumentSnapshot?
    lazy var refreshStatus: RefreshStatus = .activelyRefreshing

    lazy var collectionView: UICollectionView = {
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

        collectionView.register(MapPostImageCell.self, forCellWithReuseIdentifier: MapPostImageCell.reuseID)
        collectionView.register(MapPostVideoCell.self, forCellWithReuseIdentifier: MapPostVideoCell.reuseID)
        collectionView.register(PostLoadingCell.self, forCellWithReuseIdentifier: PostLoadingCell.reuseID)
        collectionView.delegate = self
        collectionView.dataSource = self
        
        return collectionView
    }()

    lazy var deleteIndicator = UIActivityIndicatorView()

    var titleView: GridPostTitleView
    private lazy var addMapConfirmationView = AddMapConfirmationView()
    var mapData: CustomMap?

    init(parentVC: PostParent, postsList: [MapPost], delegate: PostControllerDelegate?, title: String?, subtitle: String?, startingIndex: Int? = 0) {
        self.parentVC = parentVC
        self.postsList = IdentifiedArrayOf(uniqueElements: postsList)
        self.delegate = delegate
        self.startingIndex = startingIndex ?? 0
        postsLoaded = parentVC != .Explore
        titleView = GridPostTitleView(title: title ?? "", subtitle: subtitle ?? "")
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")

        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addMapConfirmationView.isHidden = true
        view.addSubview(addMapConfirmationView)
        addMapConfirmationView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(34)
            $0.height.equalTo(57)
            $0.bottom.equalTo(-23)
        }

        if openComments, let post = postsList.first {
            openComments(post: post, animated: true)
        }
        
        subscribeToNotifications()

        if !postsLoaded {
            DispatchQueue.global(qos: .userInitiated).async {
                self.getExploreMapsPosts()
            }

        } else if startingIndex != 0 {
            // scroll to selected row (map/post/spot)
            DispatchQueue.main.async {
                self.view.layoutIfNeeded()
                self.collectionView.scrollToItem(at: IndexPath(row: self.startingIndex, section: 0), at: .top, animated: false)
                self.startingIndex = 0
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        for cell in collectionView.visibleCells {
            if let cell = cell as? MapPostVideoCell {
                cell.reloadVideo()
            }
        }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for cell in collectionView.visibleCells {
            if let cell = cell as? MapPostVideoCell {
                cell.playerView.player?.pause()
                cell.playerView.player = nil
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    func setPosts(posts: [MapPost]) {
        postsList.append(contentsOf: posts)
        if refreshStatus != .refreshDisabled { refreshStatus = .refreshEnabled }
        collectionView.reloadData()
        if startingIndex != 0 {
            collectionView.scrollToItem(at: IndexPath(row: startingIndex, section: 0), at: .top, animated: false)
            startingIndex = 0
        }
    }
    
    private func subscribeToNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(postChanged(_:)), name: NSNotification.Name("PostChanged"), object: nil)
    }

    private func setUpNavBar() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()


        if parentVC == .Map || parentVC == .Explore {
            if !(mapData?.likers.contains(where: { $0 == UserDataModel.shared.uid }) ?? true) {
                navigationItem.rightBarButtonItem = UIBarButtonItem(
                    image: UIImage(named: "AddPlusButton")?.withRenderingMode(.alwaysOriginal),
                    style: .plain,
                    target: self,
                    action: #selector(addMapTap))
            } else {
                navigationItem.rightBarButtonItem = UIBarButtonItem()
            }
            // setting title for resetting after user joins map
            var subtitle = String(mapData?.likers.count ?? 0)
            subtitle += (mapData?.communityMap ?? false) ? " joined" : " followers"
            titleView = GridPostTitleView(title: mapData?.mapName ?? "", subtitle: subtitle)
        }
        navigationItem.titleView = titleView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout

extension GridPostViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return postsLoaded ? postsList.count : 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard !postsList.isEmpty && postsList.count > indexPath.row && postsLoaded else {
            let loadingCell = collectionView.dequeueReusableCell(withReuseIdentifier: PostLoadingCell.reuseID, for: indexPath) as? PostLoadingCell
            return loadingCell ?? UICollectionViewCell()
        }
        
        let post = postsList[indexPath.row]
        if let videoURLString = post.videoURL,
           let videoURL = URL(string: videoURLString),
           let videoCell = collectionView.dequeueReusableCell(withReuseIdentifier: MapPostVideoCell.reuseID, for: indexPath) as? MapPostVideoCell {
            videoCell.configure(post: post, parent: parentVC, url: videoURL)
            videoCell.delegate = self
            return videoCell
            
        } else if let imageCell = collectionView.dequeueReusableCell(withReuseIdentifier: MapPostImageCell.reuseID, for: indexPath) as? MapPostImageCell {
            imageCell.configure(post: post, parent: parentVC, row: indexPath.row)
            imageCell.delegate = self
            return imageCell
            
        } else {
            return UICollectionViewCell()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.frame.size
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        delegate?.indexChanged(rowsRemaining: postsList.count - indexPath.row)
        checkForExploreRefresh(index: indexPath.row)

        if let cell = cell as? MapPostImageCell {
            cell.animateLocation()
        } else if let cell = cell as? MapPostVideoCell {
            loadVideoIfNeeded(for: cell, at: indexPath)
            cell.animateLocation()
            cell.addNotifications()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let videoCell = cell as? MapPostVideoCell else {
            return
        }
        
        videoCell.playerView.player?.pause()
        videoCell.playerView.player = nil
        videoCell.removeNotifications()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollView.contentInset.top = max((scrollView.frame.height - scrollView.contentSize.height) / 2, 0)
    }

    private func loadVideoIfNeeded(for videoCell: MapPostVideoCell, at indexPath: IndexPath) {
        guard videoCell.playerView.player == nil else {
      //      videoCell.playOnDidDisplayCell()
            return
        }

        let post = postsList[indexPath.row]
        if let videoURLString = post.videoURL,
           let videoURL = URL(string: videoURLString) {
            videoCell.configureVideo(url: videoURL)
        }
    }
}

extension GridPostViewController: ContentViewerDelegate {
    func likePost(postID: String) {
        guard !postID.isEmpty, var post = self.postsList[id: postID] else {
            return
        }
        HapticGenerator.shared.play(.light)

        if post.likers.firstIndex(where: { $0 == UserDataModel.shared.uid }) != nil {
            Mixpanel.mainInstance().track(event: "PostPageUnlikePost")
            unlikePost(id: postID)
        } else {
            Mixpanel.mainInstance().track(event: "PostPageLikePost")
            likePost(id: postID)
        }
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

    func openComments(post: MapPost, animated: Bool) {
        if presentedViewController != nil { return }
        Mixpanel.mainInstance().track(event: "PostOpenComments")
        let commentsVC = CommentsController(commentsList: post.commentList, post: post)
        commentsVC.delegate = self
        present(commentsVC, animated: animated, completion: nil)
    }

    private func likePost(id: String) {
        guard !id.isEmpty, var post = self.postsList[id: id] else {
            return
        }
        post.likers.append(UserDataModel.shared.uid)
        self.postsList[id: id] = post
        collectionView.reloadData()
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.postService?.likePostDB(post: post)
        }
    }

    private func unlikePost(id: String) {
        guard !id.isEmpty, var post = self.postsList[id: id] else {
            return
        }
        
        post.likers.removeAll(where: { $0 == UserDataModel.shared.uid })
        self.postsList[id: id] = post
        collectionView.reloadData()
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.postService?.unlikePostDB(post: post)
        }
    }
    
    @objc private func postChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
              let post = userInfo["post"] as? MapPost else {
            return
        }
        
        updatePost(id: post.id, update: post)
    }
    
    private func updatePost(id: String?, update: MapPost) {
        guard let id, !id.isEmpty, self.postsList[id: id] != nil, let i = self.postsList.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        DispatchQueue.main.async {
            self.postsList[id: id] = update
            self.collectionView.reloadItems(at: [IndexPath(item: i, section: 0)])
        }
    }

    @objc func addMapTap() {
        Mixpanel.mainInstance().track(event: "MapHeaderJoinTap")
        guard let map = mapData else { return }

        mapData?.likers.append(UserDataModel.shared.uid)
        if mapData?.communityMap ?? false { mapData?.memberIDs.append(UserDataModel.shared.uid) }
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.mapService?.followMap(customMap: map) { _ in }
        }

        toggleAddMapView()
        setUpNavBar()

        guard let mapData = mapData else { return }
        NotificationCenter.default.post(Notification(name: Notification.Name("EditMap"), object: nil, userInfo: ["map": mapData as Any]))
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

extension GridPostViewController: CommentsDelegate {
    func openProfileFromComments(user: UserProfile) {
        openProfile(user: user)
    }
}
