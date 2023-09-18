//
//  SpotController.swift
//  Spot
//
//  Created by Kenny Barone on 7/7/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Combine
import Firebase
import Photos
import PhotosUI
import Mixpanel

final class SpotController: UIViewController {
    typealias Input = SpotViewModel.Input
    typealias Output = SpotViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    enum PostUpdateType: String {
        case PostUpdate
        case NewComment
        case CommentUpdate
        case None
    }

    enum Section: Hashable {
        case main(spot: Spot, sortMethod: SpotViewModel.SortMethod)
    }

    enum Item: Hashable {
        case item(post: Post)
    }

    let viewModel: SpotViewModel
    var subscriptions = Set<AnyCancellable>()

    let refresh = PassthroughSubject<Bool, Never>()
    let postListener = PassthroughSubject<(forced: Bool, fetchNewPosts: Bool, commentInfo: (post: Post?, endDocument: DocumentSnapshot?, paginate: Bool)), Never>()
    let sort = PassthroughSubject<(sort: SpotViewModel.SortMethod, useEndDoc: Bool), Never>()

    var disablePagination: Bool {
        switch viewModel.activeSortMethod {
        case .New: return viewModel.disableRecentPagination
        case .Hot: return viewModel.disableTopPagination
        }
    }

    private var emptyStateHidden = true
    var scrollToPostID: String?

    weak var cameraPicker: UIImagePickerController?
    weak var galleryPicker: PHPickerViewController?

    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            switch item {
            case .item(post: let post):
                let cell = tableView.dequeueReusableCell(withIdentifier: SpotPostCell.reuseID, for: indexPath) as? SpotPostCell
                cell?.configure(post: post, parent: .SpotPage)
                cell?.delegate = self
                return cell
            }
        }
        return dataSource
    }()

    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = UIScreen.main.bounds.height / 2
        tableView.backgroundColor = SpotColors.HeaderGray.color
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        tableView.clipsToBounds = true
        tableView.register(SpotPostCell.self, forCellReuseIdentifier: SpotPostCell.reuseID)
        tableView.register(SpotOverviewHeader.self, forHeaderFooterViewReuseIdentifier: SpotOverviewHeader.reuseID)
        return tableView
    }()

    private lazy var activityFooterView = ActivityFooterView()

    private lazy var activityIndicator = UIActivityIndicatorView()
    private(set) lazy var emptyState = SpotEmptyState() {
        didSet {
            emptyStateHidden = emptyState.isHidden
        }
    }

    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
        return refreshControl
    }()

    private lazy var newPostsButton: GradientButton = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0.38, green: 0.718, blue: 0.976, alpha: 1).cgColor
        ]
        layer.locations = [0, 1]

        let button = GradientButton(
            layer: layer,
            image: UIImage(named: "RefreshIcon") ?? UIImage(),
            text: "Load 1 more post",
            cornerRadius: 20)
        button.isHidden = true
        button.addTarget(self, action: #selector(loadNewPostsTap), for: .touchUpInside)
        return button
    }()


    private lazy var textFieldFooter = SpotTextFieldFooter(parent: .SpotPage)
    lazy var moveCloserFooter = SpotMoveCloserFooter()

    var isRefreshingPagination = false {
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

    var animateTopActivityIndicator = false {
        didSet {
            DispatchQueue.main.async {
                if self.animateTopActivityIndicator {
                    self.tableView.bringSubviewToFront(self.activityIndicator)
                    self.activityIndicator.startAnimating()
                }
            }
        }
    }

    init(viewModel: SpotViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        edgesForExtendedLayout = []
    }

    deinit {
        print("deinit spot")
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.addUserToHereNow()
        Mixpanel.mainInstance().track(event: "SpotPageAppeared")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SpotColors.SpotBlack.color

        tableView.refreshControl = refreshControl
        activityFooterView.isHidden = true
        tableView.tableFooterView = activityFooterView
        view.addSubview(tableView)

        view.addSubview(emptyState)
        emptyState.configure(spot: viewModel.cachedSpot)
        emptyState.isHidden = true
        emptyState.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(newPostsButton)
        newPostsButton.snp.makeConstraints {
            $0.top.equalTo(42)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(200)
            $0.height.equalTo(44)
        }

        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(100)
            $0.width.height.equalTo(30)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.color = .white
        activityIndicator.startAnimating()

        view.addSubview(textFieldFooter)
        textFieldFooter.delegate = self
        textFieldFooter.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(113)
        }

        tableView.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.bottom.equalTo(textFieldFooter.snp.top)
        }

        view.addSubview(moveCloserFooter)
        moveCloserFooter.delegate = self
        moveCloserFooter.snp.makeConstraints {
            $0.edges.equalTo(textFieldFooter)
        }

        let input = Input(
            refresh: refresh,
            //    spotListenerForced: spotListenerForced,
            postListener: postListener,
            sort: sort
        )

        let output = viewModel.bind(to: input)
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)
                self?.isRefreshingPagination = false
                self?.animateTopActivityIndicator = false
                self?.refreshControl.endRefreshing()

                // end activity animation on empty state or if returning a post
                if self?.viewModel.postsAreEmpty() ?? false || !snapshot.itemIdentifiers.isEmpty {
                    self?.activityIndicator.stopAnimating()
                }

                // call in case spotName wasn't passed through
                self?.setUpNavBar()
                self?.emptyState.isHidden = !(self?.viewModel.postsAreEmpty() ?? false)

                // toggle new posts view
                if !(self?.viewModel.addedPostIDs.isEmpty ?? true) && (self?.viewModel.activeSortMethod == .New) {
                    self?.newPostsButton.isHidden = false
                    let postCount = self?.viewModel.addedPostIDs.count ?? 0
                    var text = "Load \(postCount) new post"
                    if postCount > 1 { text += "s" }
                    self?.newPostsButton.label.text = text
                } else {
                    self?.newPostsButton.isHidden = true
                }

                if let postID = self?.scrollToPostID, let selectedRow = self?.viewModel.getSelectedIndexFor(postID: postID) {
                    // scroll to selected row on post upload
                    let path = IndexPath(row: selectedRow, section: 0)
                    self?.tableView.scrollToRow(at: path, at: .middle, animated: true)
                    self?.scrollToPostID = nil
                }
            }
            .store(in: &subscriptions)


        refresh.send(true)
        postListener.send((forced: false, fetchNewPosts: false, commentInfo: (post: nil, endDocument: nil, paginate: false)))
        sort.send((sort: .New, useEndDoc: true))

        subscribeToPostListener()
        addFooter()

        viewModel.setSeen()
    }

    private func setUpNavBar() {
        navigationController?.setUpOpaqueNav(backgroundColor: SpotColors.HeaderGray.color)
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont(name: "UniversCE-Black", size: 20) as Any
        ]
        navigationItem.title = viewModel.cachedSpot.spotName
    }

    private func subscribeToPostListener() {
        guard let spotID = viewModel.cachedSpot.id else { return }
        let request = Firestore.firestore()
            .collection(FirebaseCollectionNames.posts.rawValue)
            .limit(to: 25)
            .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
        let spotQuery = request.whereField(FirebaseCollectionFields.spotID.rawValue, isEqualTo: spotID)

        spotQuery.snapshotPublisher(includeMetadataChanges: true)
            .removeDuplicates()
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] completion in
                    guard let self,
                          !completion.metadata.isFromCache,
                          !completion.documentChanges.isEmpty,
                          self.viewModel.activeSortMethod == .New,
                          (!self.emptyStateHidden || !self.datasource.snapshot().itemIdentifiers.isEmpty)
                    else { return }

                    let addedIDs = completion.documentChanges.filter({ $0.type == .added }).map({ $0.document.documentID })
                    let addedDocs = completion.documents.filter({ addedIDs.contains($0.documentID) })
                    let addedPostIDs = self.filterAddedPostIDs(docs: addedDocs)

                    viewModel.addedPostIDs.insert(contentsOf: addedPostIDs, at: 0)
                    viewModel.addedPostIDs.removeDuplicates()
                    guard addedPostIDs.isEmpty else {
                        // add new post to new posts button
                        refresh.send(false)
                        return
                    }

                    viewModel.removedPostIDs = completion.documentChanges.filter({ $0.type == .removed }).map({ $0.document.documentID })
                    viewModel.modifiedPostIDs = completion.documentChanges.filter({ $0.type == .modified }).map({ $0.document.documentID })

                    // block seenList and other unnecessary updates
                    let postUpdateData = getPostUpdateType(documents: completion.documents)
                    let postUpdateType = postUpdateData.0
                    switch postUpdateType {
                    case .CommentUpdate:
                        // comment like / delete
                        if let post = postUpdateData.1 {
                            refresh.send(true)
                            postListener.send((
                                forced: true,
                                fetchNewPosts: false,
                                commentInfo: (
                                    post: post,
                                    endDocument: nil,
                                    paginate: false
                                )))

                        } else {
                            fallthrough
                        }

                    case .NewComment:
                        // show new comment as loadable from parent post or last comment
                        if let post = postUpdateData.1 {
                            print("new comment")
                            self.viewModel.updateParentPostCommentCount(post: post)
                            self.refresh.send(false)
                        }

                    case .PostUpdate:
                        // post like
                        refresh.send(true)
                        postListener.send((
                            forced: true,
                            fetchNewPosts: false,
                            commentInfo: (
                                post: nil,
                                endDocument: nil,
                                paginate: false
                            )))

                    default:
                        return
                    }
                })
            .store(in: &subscriptions)
    }

    func addFooter() {
        if viewModel.cachedSpot.userInRange() {
            textFieldFooter.isHidden = false
            moveCloserFooter.isHidden = true
        } else {
            textFieldFooter.isHidden = true
            moveCloserFooter.isHidden = false
        }
    }

    // return PostUpdateType + post for comment updates if applicable
    private func getPostUpdateType(documents: [QueryDocumentSnapshot]) -> (PostUpdateType, Post?) {
        if !viewModel.removedPostIDs.isEmpty {
            return (.PostUpdate, nil)
        }
        for doc in documents {
            let post = try? doc.data(as: Post.self)
            if let post, var cachedPost = viewModel.presentedPosts[id: post.id ?? ""] {
                if post.likers.count != cachedPost.likers.count {
                    return (.PostUpdate, nil)
                }

                if post.commentCount ?? 0 > cachedPost.commentCount ?? 0 {
                    return (.NewComment, post)
                } else if post.commentCount ?? 0 < cachedPost.commentCount ?? 0 {
                    // update comment count but still send through cached post so we know which comments have already been fetched (postChildren)
                    cachedPost.commentCount = post.commentCount ?? 0
                    return (.CommentUpdate, cachedPost)
                }

                if !(cachedPost.postChildren?.isEmpty ?? true) {
                    // check for comment like updates
                    for i in 0..<(cachedPost.postChildren?.count ?? 0) {
                        guard let j = post.commentIDs?.firstIndex(where: { $0 == cachedPost.postChildren?[i].id ?? ""}) else { continue }
                        if post.commentLikeCounts?[safe: j] ?? 0 != cachedPost.postChildren?[i].likers.count {
                            return (.CommentUpdate, cachedPost)
                        }
                    }
                }
            }
        }
        return (.None, nil)
    }

    private func filterAddedPostIDs(docs: [QueryDocumentSnapshot]) -> [String] {
        var addedPosts = [Post]()
        let lastPostTimestamp = viewModel.presentedPosts.first?.timestamp ?? Timestamp(date: Date(timeIntervalSince1970: 0))
        for doc in docs {
            guard let post = try? doc.data(as: Post.self) else { continue }
            // check to ensure this is actually a new post and not just one entering at the end of the query
            guard post.timestamp.seconds > lastPostTimestamp.seconds else { continue }
            let presentedPostIDs = viewModel.presentedPosts.map({ $0.id ?? "" })
            // check to make sure its not a new post sneaking through after upload / deleted post after delete
            guard !UserDataModel.shared.deletedPostIDs.contains(doc.documentID), !(presentedPostIDs.contains(doc.documentID)) else {
                continue
            }
            addedPosts.append(post)
        }
        return addedPosts.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds }).map({ $0.id ?? "" })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func loadNewPostsTap() {
        HapticGenerator.shared.play(.soft)
        Mixpanel.mainInstance().track(event: "SpotPageLoadNewPostsTap")
        refresh.send(true)
        postListener.send((
            forced: true,
            fetchNewPosts: true,
            commentInfo: (
                post: nil,
                endDocument: nil,
                paginate: false
            )))

        DispatchQueue.main.async {
            self.animateTopActivityIndicator = true
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .middle, animated: true)
        }
    }

    @objc func forceRefresh() {
        Mixpanel.mainInstance().track(event: "SpotPagePullToRefresh")
        refresh.send(true)
        postListener.send((
            forced: false,
            fetchNewPosts: false,
            commentInfo: (
                post: nil,
                endDocument: nil,
                paginate: false
            )))
        sort.send((sort: viewModel.activeSortMethod, useEndDoc: false))

        DispatchQueue.main.async {
            self.refreshControl.beginRefreshing()
        }
    }

    @objc func shareTap() {

    }
}

