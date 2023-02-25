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

protocol PostControllerDelegate: AnyObject {
    func indexChanged(rowsRemaining: Int)
}

final class PostController: UIViewController {
    
    private(set) lazy var allPostsViewController: AllPostsViewController = {
        return AllPostsViewController()
    }()
    
    private(set) lazy var nearbyPostsViewController: NearbyPostsViewController = {
        let nearby = NearbyPostsViewController()
        
        return nearby
    }()
    
    private(set) lazy var pageViewController: UIPageViewController = {
        let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        
        pageViewController.delegate = self
        pageViewController.dataSource = self
        return pageViewController
    }()
    

    let db = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

    var parentVC: PostParent
    weak var delegate: PostControllerDelegate?

    lazy var selectedSegment: FeedFetchType = .MyPosts {
        didSet {
            postsList = selectedSegmentPosts
            DispatchQueue.main.async {
                self.titleView.setButtonBar(animated: true, selectedSegment: self.selectedSegment)
                self.selectedPostIndex = self.selectedSegmentPostIndex
                self.contentTable.reloadData()
                self.contentTable.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: false)
            }
        }
    }
    var postsList: [MapPost] {
        didSet {
            DispatchQueue.main.async { self.contentTable.isScrollEnabled = self.postsList.count > 1 }
        }
    }
    var myPostsFetched = false
    lazy var localPosts: [MapPost] = []
    lazy var myPosts: [MapPost] = []
    lazy var friendsFetchIDs: [String] = []
    lazy var mapFetchIDs: [String] = []
    var friendsListener, mapsListener: ListenerRegistration?
    lazy var homeFetchGroup = DispatchGroup()
    var homeFetchLeaveCount = 0
    var friendsPostEndDocument: DocumentSnapshot?
    var nearbyPostEndDocument: DocumentSnapshot?
    lazy var myPostsRefreshStatus: RefreshStatus = .refreshDisabled
    let myPostsFetchLimit: Int = 5
    lazy var reachedEndOfFriendPosts = false {
        didSet {
            if reachedEndOfFriendPosts && reachedEndOfMapPosts { myPostsRefreshStatus = .refreshDisabled }
        }
    }
    lazy var reachedEndOfMapPosts = false {
        didSet {
            if reachedEndOfFriendPosts && reachedEndOfMapPosts { myPostsRefreshStatus = .refreshDisabled }
        }
    }

    var nearbyPostsFetched = false
    lazy var nearbyPosts: [MapPost] = []
    var mapPostEndDocument: DocumentSnapshot?
    lazy var nearbyRefreshStatus: RefreshStatus = .refreshDisabled

    lazy var contentTable: UITableView = {
        let view = UITableView()
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIScreen.main.bounds.height, right: 0)
        view.backgroundColor = .black
        view.separatorStyle = .none
        view.isScrollEnabled = false
        view.isPrefetchingEnabled = true
        view.showsVerticalScrollIndicator = false
        view.scrollsToTop = false
        view.contentInsetAdjustmentBehavior = .never
        view.shouldIgnoreContentInsetAdjustment = true
        // inset to show button view
        view.register(ContentViewerCell.self, forCellReuseIdentifier: ContentViewerCell.reuseID)
        view.register(ContentLoadingCell.self, forCellReuseIdentifier: ContentLoadingCell.reuseID)
        return view
    }()
    
    var rowHeight: CGFloat {
        return contentTable.bounds.height - 0.01
    }
    var currentRowContentOffset: CGFloat {
        return rowHeight * CGFloat(selectedPostIndex)
    }
    var maxRowContentOffset: CGFloat {
        return rowHeight * CGFloat(postsList.count - 1)
    }

    private lazy var titleView = PostTitleView()

    var openComments = false
    var imageViewOffset = false {
        didSet {
            DispatchQueue.main.async { self.contentTable.isScrollEnabled = !self.imageViewOffset }
        }
    }
    var tableViewOffset = false {
        didSet {
            DispatchQueue.main.async { self.setCellOffsets(offset: self.tableViewOffset) }
        }
    }

    lazy var deleteIndicator = CustomActivityIndicator()
    
    lazy var mapPostService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()

    private lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()

    var myPostIndex = 0
    var nearbyPostIndex = 0
    var selectedPostIndex = 0 {
        didSet {
            updatePostIndex()
        }
    }

    var scrolledToInitialRow = false
    var isPageControllerTransitioning = false
    var animatingToNextRow = false {
        didSet {
            contentTable.isScrollEnabled = !animatingToNextRow
        }
    }

    // pause image loading during row animation to avoid laggy scrolling
    init(parentVC: PostParent, postsList: [MapPost], selectedPostIndex: Int? = 0, title: String? = "") {
        self.parentVC = parentVC
        // sort posts on first open to avoid having to load all of the rows before the current post
        self.postsList = postsList
        self.selectedPostIndex = selectedPostIndex ?? 0

        super.init(nibName: nil, bundle: nil)

        setUpView()
        addNotifications()
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
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cancelDownloads()
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
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
    }

    func setUpView() {
        contentTable.prefetchDataSource = self
        contentTable.dataSource = self
        contentTable.delegate = self
        view.addSubview(contentTable)
        contentTable.reloadData()
        contentTable.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        if parentVC == .Home {
            titleView.setUp(parentVC: parentVC, selectedSegment: selectedSegment)
            titleView.myWorldButton.addTarget(self, action: #selector(myWorldTap), for: .touchUpInside)
            titleView.nearbyButton.addTarget(self, action: #selector(nearbyTap), for: .touchUpInside)
            titleView.findFriendsButton.addTarget(self, action: #selector(findFriendsTap), for: .touchUpInside)

        } else {
            titleView.setUp(parentVC: parentVC, selectedSegment: nil)
            updatePostIndex()
        }

        navigationItem.titleView = titleView
        
        if parentVC != .Home {
            DispatchQueue.main.async {
                self.contentTable.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: false)
            }
        }
    }

    func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCommentChange(_:)), name: NSNotification.Name(("CommentChange")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyImageChange(_:)), name: NSNotification.Name("PostImageChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCitySet), name: NSNotification.Name("UserCitySet"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name(("NewPost")), object: nil)
    }
}

// MARK: UIPageViewControllerDelegate and UIPageViewControllerDataSource

extension PostController: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        isPageControllerTransitioning = true
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        
        guard completed,
              let currentViewController = pageViewController.viewControllers?.first,
              let previewViewController = previousViewControllers.first,
              currentViewController != previewViewController else {
            isPageControllerTransitioning = false
            return
        }
        
        isPageControllerTransitioning = false
        if previewViewController == allPostsViewController {
            
        } else if previewViewController == nearbyPostsViewController {
            
        }
        
        // Update segment control
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        <#code#>
    }
}
