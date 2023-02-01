//
//  PostController.swift
//  Spot
//
//  Created by kbarone on 1/8/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import FirebaseFunctions
import MapKit
import Mixpanel
import SnapKit
import UIKit

enum PostParent: String {
    case Home
    case Spot
    case Map
    case Profile
    case Notifications
}

final class PostController: UIViewController {
    let db = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

    var parentVC: PostParent
    var postsList: [MapPost]

    lazy var contentTable: UITableView = {
        let view = UITableView()
        view.backgroundColor = .black
        view.separatorStyle = .none
        view.isScrollEnabled = false
        // inset to show button view
        view.register(ContentViewerCell.self, forCellReuseIdentifier: "ContentCell")
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        return view
    }()

    private lazy var titleView = UIView()
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1)
        label.font = UIFont(name: "UniversCE-Black", size: 16.5)
        return label
    }()
    private lazy var backArrow: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "BackArrow"), for: .normal)
        button.addTarget(self, action: #selector(backTap), for: .touchUpInside)
        return button
    }()
    private lazy var moreButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "Elipses"), for: .normal)
        button.addTarget(self, action: #selector(elipsesTap), for: .touchUpInside)
        return button
    }()

    private lazy var buttonView = PostButtonView()

    unowned var containerDrawerView: DrawerView?
    var openComments = false
    
    lazy var deleteIndicator = CustomActivityIndicator()
    
    lazy var mapPostService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()

    private lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()
    
    var selectedPostIndex = 0 {
        didSet {
            updatePostIndex()
        }
    }

    private var scrolledToInitialRow = false

    init(parentVC: PostParent, postsList: [MapPost], selectedPostIndex: Int? = 0) {
        self.parentVC = parentVC
        self.postsList = postsList
        super.init(nibName: nil, bundle: nil)

        titleLabel.text = parentVC.rawValue
        self.selectedPostIndex = selectedPostIndex ?? 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        removeTableAnimations()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        containerDrawerView?.configure(canDrag: false, swipeDownToDismiss: false, startingPosition: .top)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PostPageOpen")
        
        if openComments {
            openComments(row: selectedPostIndex, animated: true)
            openComments = false
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        edgesForExtendedLayout = [.top]
        setUpView()
        addNotifications()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cancelDownloads()
    }

    override func viewDidLayoutSubviews() {
        if !scrolledToInitialRow {
            DispatchQueue.main.async {
                // move to universal scroll to row at override function
                let startingOffset: CGFloat = (UIScreen.main.bounds.height - 95) * CGFloat(self.selectedPostIndex)
                self.contentTable.contentOffset.y = startingOffset
                self.scrolledToInitialRow = true
                print("offset", self.contentTable.contentOffset.y)
            }
        }
    }
    
    func cancelDownloads() {
        // cancel image loading operations and reset map
        for op in PostImageModel.shared.loadingOperations {
            guard let imageLoader = PostImageModel.shared.loadingOperations[op.key] else { continue }
            imageLoader.cancel()
            PostImageModel.shared.loadingOperations.removeValue(forKey: op.key)
        }
        PostImageModel.shared.loadingQueue.cancelAllOperations()
    }
    
    func setUpNavBar() {
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    func setUpView() {
        contentTable.dataSource = self
        contentTable.delegate = self
        //    contentTable.prefetchDataSource = self
        view.addSubview(contentTable)
        contentTable.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(titleView)
        titleView.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.height.equalTo(100)
        }

        titleView.addSubview(backArrow)
        backArrow.snp.makeConstraints {
            $0.leading.equalTo(5)
            $0.top.equalTo(50)
            $0.width.equalTo(53)
            $0.height.equalTo(49)
        }

        titleView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalTo(backArrow)
        }

        titleView.addSubview(moreButton)
        moreButton.snp.makeConstraints {
            $0.centerY.equalTo(backArrow)
            $0.trailing.equalTo(-8)
            $0.height.equalTo(14.5)
            $0.width.equalTo(40.2)
        }

        view.addSubview(buttonView)
        buttonView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(95)
        }

        buttonView.commentButton.addTarget(self, action: #selector(commentsTap), for: .touchUpInside)
        buttonView.likeButton.addTarget(self, action: #selector(likeTap), for: .touchUpInside)
        // set current comment / like info and look for changes
        updatePostIndex()
    }

    func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCommentChange(_:)), name: NSNotification.Name(("CommentChange")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name("DeletePost"), object: nil)
    }

    @objc func notifyCommentChange(_ notification: NSNotification) {
        guard let commentList = notification.userInfo?["commentList"] as? [MapComment] else { return }
        guard let postID = notification.userInfo?["postID"] as? String else { return }
        if let i = postsList.firstIndex(where: { $0.id == postID }) {
            postsList[i].commentCount = max(0, commentList.count - 1)
            postsList[i].commentList = commentList
            DispatchQueue.main.async { self.contentTable.reloadData() }
        }
    }
    
    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        DispatchQueue.main.async {
            if let index = self.postsList.firstIndex(where: { $0.id == post.id }) {
                self.deletePostLocally(index: index)
            }
        }
    }

    func setSeen(post: MapPost) {
        /// set seen on map
        db.collection("posts").document(post.id ?? "").updateData(["seenList": FieldValue.arrayUnion([uid])])
        NotificationCenter.default.post(Notification(name: Notification.Name("PostOpen"), object: nil, userInfo: ["post": post as Any]))
        /// show notification as seen
        updateNotifications(postID: post.id ?? "")
    }

    func checkForUpdates(postID: String, index: Int) {
        Task {
            /// update just the necessary info -> comments and likes
            guard let post = try? await mapPostService?.getPost(postID: postID) else {
                return
            }

            if let i = self.postsList.firstIndex(where: { $0.id == postID }) {
                self.postsList[i].commentList = post.commentList
                self.postsList[i].commentCount = post.commentCount
                self.postsList[i].likers = post.likers
                if index != self.selectedPostIndex { return }
                /// update button view if this is the current post
                updateButtonView()
            }
        }
    }

    func updateNotifications(postID: String) {
        db.collection("users").document(uid).collection("notifications").whereField("postID", isEqualTo: postID).getDocuments { snap, _ in
            guard let snap = snap else { return }
            for doc in snap.documents {
                doc.reference.updateData(["seen": true])
            }
        }
    }

    private func updatePostIndex() {
        guard let post = postsList[safe: selectedPostIndex] else { return }
        DispatchQueue.global().async {
            self.setSeen(post: post)
            self.checkForUpdates(postID: post.id ?? "", index: self.selectedPostIndex)
        }
        DispatchQueue.main.async {
            self.updateButtonView()
        }
    }

    func updateButtonView() {
        buttonView.setCommentsAndLikes(post: postsList[selectedPostIndex])
    }

    func exitPosts() {
        for cell in contentTable.visibleCells { cell.layer.removeAllAnimations() }
        containerDrawerView?.closeAction()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostLike"), object: nil)
    }
}
