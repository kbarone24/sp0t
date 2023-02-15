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

    // values for feed fetch
    enum FetchType {
        case MyPosts
        case NearbyPosts
    }
    lazy var selectedSegment: FetchType = .MyPosts {
        didSet {
            postsList = selectedSegmentPosts
            DispatchQueue.main.async {
                self.setButtonBar(animated: true)
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

    var selectedSegmentPosts: [MapPost] {
        return selectedSegment == .MyPosts ? myPosts : nearbyPosts
    }
    var selectedSegmentPostIndex: Int {
        return selectedSegment == .MyPosts ? myPostIndex : nearbyPostIndex
    }
    var selectedRefreshStatus: RefreshStatus {
        return selectedSegment == .MyPosts ? myPostsRefreshStatus : nearbyRefreshStatus
    }

    lazy var contentTable: UITableView = {
        let view = UITableView()
        view.contentInset = UIEdgeInsets(top: -50, left: 0, bottom: UIScreen.main.bounds.height, right: 0)
        view.backgroundColor = .black
        view.separatorStyle = .none
        view.isScrollEnabled = false
        view.isPrefetchingEnabled = true
        view.showsVerticalScrollIndicator = false
        view.scrollsToTop = false
        // inset to show button view
        view.register(ContentViewerCell.self, forCellReuseIdentifier: "ContentCell")
        view.register(ContentLoadingCell.self, forCellReuseIdentifier: "LoadingCell")
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

    private lazy var titleView = UIView()
    //TODO: import real fonts for these buttons
    lazy var myWorldButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let attText = AttributedString("My World", attributes: AttributeContainer([
            .font: UIFont(name: "UniversCE-Black", size: 15) as Any,
            .foregroundColor: UIColor.white
        ]))
        configuration.attributedTitle = attText
        let button = UIButton(configuration: configuration)
        button.alpha = 0.5
        button.addShadow(shadowColor: UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor, opacity: 1, radius: 4, offset: CGSize(width: 0, height: 1.5))
        button.addTarget(self, action: #selector(myWorldTap), for: .touchUpInside)
        return button
    }()
    lazy var nearbyButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let attText = AttributedString("Nearby", attributes: AttributeContainer([
            .font: UIFont(name: "UniversCE-Black", size: 15) as Any,
            .foregroundColor: UIColor.white
        ]))
        configuration.attributedTitle = attText
        let button = UIButton(configuration: configuration)
        button.alpha = 0.5
        button.addShadow(shadowColor: UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor, opacity: 1, radius: 4, offset: CGSize(width: 0, height: 1.5))
        button.addTarget(self, action: #selector(nearbyTap), for: .touchUpInside)
        return button
    }()
    lazy var buttonBar: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.95)
        view.layer.cornerRadius = 1
        return view
    }()
    private lazy var findFriendsButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "FindFriendsNavIcon"), for: .normal)
        button.addTarget(self, action: #selector(findFriendsTap), for: .touchUpInside)
        return button
    }()
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
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

        titleLabel.text = (title ?? "" != "") ? title : parentVC.rawValue
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
        if parentVC == .Home {
            DispatchQueue.global(qos: .userInitiated).async { self.getMyPosts() }
        }
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
        navigationController?.setNavigationBarHidden(true, animated: true)
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

        let statusBarOffset: CGFloat = UserDataModel.shared.screenSize == 0 ? 20 : 40
        view.addSubview(titleView)
        titleView.snp.makeConstraints {
            $0.top.equalTo(statusBarOffset)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(60)
        }

        if parentVC == .Home {
            titleView.addSubview(myWorldButton)
            myWorldButton.snp.makeConstraints {
                $0.trailing.equalTo(titleView.snp.centerX).offset(-5)
                $0.centerY.equalToSuperview()
            }
            titleView.addSubview(nearbyButton)
            nearbyButton.snp.makeConstraints {
                $0.leading.equalTo(titleView.snp.centerX).offset(5)
                $0.centerY.equalToSuperview()
            }
            titleView.addSubview(buttonBar)
            setButtonBar(animated: false)
            titleView.addSubview(findFriendsButton)
            findFriendsButton.snp.makeConstraints {
                $0.leading.equalTo(5)
                $0.top.equalTo(myWorldButton).offset(-10)
                $0.width.equalTo(62)
                $0.height.equalTo(46)
            }

        } else {
            titleView.addSubview(backArrow)
            backArrow.snp.makeConstraints {
                $0.leading.equalTo(5)
                $0.top.equalTo(50)
                $0.width.equalTo(53)
                $0.height.equalTo(49)
            }
            titleView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints {
                $0.centerY.equalTo(backArrow)
                $0.leading.equalTo(backArrow.snp.trailing).offset(10)
                $0.trailing.equalTo(-68)
            }
            updatePostIndex()
        }

        DispatchQueue.main.async {
           // self.contentTable.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: false)
        }
    }

    func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCommentChange(_:)), name: NSNotification.Name(("CommentChange")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyImageChange(_:)), name: NSNotification.Name("PostImageChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCitySet), name: NSNotification.Name("UserCitySet"), object: nil)
    }
}
