//
//  PopViewModel.swift
//  Spot
//
//  Created by Kenny Barone on 8/29/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//


import Foundation
import UIKit
import Combine
import Firebase
import Photos
import PhotosUI
import Mixpanel

final class PopController: UIViewController {
    typealias Input = PopViewModel.Input
    typealias Output = PopViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    enum PostUpdateType: String {
        case PostUpdate
        case NewComment
        case CommentUpdate
        case None
    }

    enum Section: Hashable {
        case main(pop: Spot, sortMethod: PopViewModel.SortMethod)
    }

    enum Item: Hashable {
        case item(post: Post)
    }

    let viewModel: PopViewModel
    var subscriptions = Set<AnyCancellable>()

    let refresh = PassthroughSubject<Bool, Never>()
 //   private let spotListenerForced = PassthroughSubject<Bool, Never>()
    let postListener = PassthroughSubject<(forced: Bool, commentInfo: (post: Post?, endDocument: DocumentSnapshot?)), Never>()
    let sort = PassthroughSubject<(sort: PopViewModel.SortMethod, useEndDoc: Bool), Never>()

    var disablePagination: Bool {
        switch viewModel.activeSortMethod {
        case .New: return viewModel.disableRecentPagination
        case .Hot: return viewModel.disableTopPagination
        }
    }

    private var emptyStateHidden = true
    var scrollToPostID: String?
    var isScrollingToTop = false

    weak var cameraPicker: UIImagePickerController?
    weak var galleryPicker: PHPickerViewController?

    private(set) lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            switch item {
            case .item(post: let post):
                let cell = tableView.dequeueReusableCell(withIdentifier: SpotPostCell.reuseID, for: indexPath) as? SpotPostCell
                cell?.configure(post: post, parent: .PopPage)
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
        tableView.register(PopOverviewHeader.self, forHeaderFooterViewReuseIdentifier: PopOverviewHeader.reuseID)
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


    private lazy var textFieldFooter = SpotTextFieldFooter(parent: .PopPage)
    lazy var moveCloserFooter = SpotMoveCloserFooter()
    private lazy var timesUpFooter = PopTimesUpFooter()

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

    init(viewModel: PopViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        edgesForExtendedLayout = []
    }

    deinit {
        print("deinit pop")
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
        Mixpanel.mainInstance().track(event: "PopPageAppeared")
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
        emptyState.configure(spot: viewModel.cachedPop)
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

        view.addSubview(timesUpFooter)
        timesUpFooter.snp.makeConstraints {
            $0.edges.equalTo(textFieldFooter)
        }

        let input = Input(
            refresh: refresh,
            postListener: postListener,
            sort: sort
        )

        let output = viewModel.bind(to: input)
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                print("sink", snapshot.itemIdentifiers.count)
                self?.datasource.apply(snapshot, animatingDifferences: false)

                self?.isRefreshingPagination = false
                self?.animateTopActivityIndicator = false
                self?.refreshControl.endRefreshing()

                // end activity animation on empty state or if returning a post
                if self?.viewModel.postsAreEmpty() ?? false || !snapshot.itemIdentifiers.isEmpty {
                    self?.activityIndicator.stopAnimating()
                }

                // call in case pop name wasn't passed through
                self?.setUpNavBar()
                self?.addFooter()

                self?.emptyState.isHidden = !(self?.viewModel.postsAreEmpty() ?? false)
                self?.toggleNewPostsView()

                if let postID = self?.scrollToPostID, let selectedRow = self?.viewModel.getSelectedIndexFor(postID: postID) {
                    // scroll to selected row on post upload
                    let path = IndexPath(row: selectedRow, section: 0)
                    self?.tableView.scrollToRow(at: path, at: .middle, animated: true)
                    self?.scrollToPostID = nil
                }
            }
            .store(in: &subscriptions)


        refresh.send(true)
        postListener.send((forced: false, commentInfo: (post: nil, endDocument: nil)))
        sort.send((sort: .New, useEndDoc: true))

        subscribeToPostListener()
        addFooter()
        NotificationCenter.default.addObserver(self, selector: #selector(timesUp), name: Notification.Name("PopTimesUp"), object: nil)

        viewModel.setSeen()
    }

    private func setUpNavBar() {
        navigationController?.setUpOpaqueNav(backgroundColor: UIColor(hexString: "39B8FF"))
        navigationItem.titleView = PopTitleView(popName: viewModel.cachedPop.spotName, hostSpot: viewModel.cachedPop.hostSpotName ?? "")
    }

    private func subscribeToPostListener() {
        guard let popID = viewModel.cachedPop.id else { return }
        let request = Firestore.firestore()
            .collection(FirebaseCollectionNames.posts.rawValue)
            .limit(to: 25)
            .order(by: PostCollectionFields.timestamp.rawValue, descending: true)
        let popQuery = request.whereField(PostCollectionFields.popID.rawValue, isEqualTo: popID)

        popQuery.snapshotPublisher(includeMetadataChanges: true)
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
                    if !addedPostIDs.isEmpty {
                        // add new post to new posts button
                        refresh.send(false)
                        return
                    }
                })
            .store(in: &subscriptions)
    }

    func addFooter() {
        if !viewModel.cachedPop.popIsActive {
            textFieldFooter.isHidden = true
            moveCloserFooter.isHidden = true
            timesUpFooter.isHidden = false
        }

        else if viewModel.cachedPop.userInRange() {
            textFieldFooter.isHidden = false
            moveCloserFooter.isHidden = true
            timesUpFooter.isHidden = true

        } else {
            textFieldFooter.isHidden = true
            moveCloserFooter.isHidden = false
            timesUpFooter.isHidden = true
        }
    }

    private func filterAddedPostIDs(docs: [QueryDocumentSnapshot]) -> [String] {
        var addedPosts = [Post]()
        let lastPostTimestamp = viewModel.presentedPosts.first?.timestamp ?? Timestamp()
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

    private func toggleNewPostsView() {
        // toggle new posts view
        if !(viewModel.addedPostIDs.isEmpty) && (viewModel.activeSortMethod == .New) {
            newPostsButton.isHidden = false
            let postCount = viewModel.addedPostIDs.count
            var text = "Load \(postCount) new post"
            if postCount > 1 { text += "s" }
            newPostsButton.label.text = text
        } else {
            newPostsButton.isHidden = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func loadNewPostsTap() {
        HapticGenerator.shared.play(.soft)
        Mixpanel.mainInstance().track(event: "PopPageLoadNewPostsTap")

        self.isScrollingToTop = true
        DispatchQueue.main.async {
            self.animateTopActivityIndicator = true
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .middle, animated: true)
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        // wait for animation to finish to send refresh event
        if isScrollingToTop {
            refresh.send(true)
            postListener.send((
                forced: false,
                commentInfo: (
                    post: nil,
                    endDocument: nil
                )
            ))
            sort.send((sort: .New, useEndDoc: false))

            isScrollingToTop = false
        }
    }

    @objc func forceRefresh() {
        Mixpanel.mainInstance().track(event: "PopPagePullToRefresh")
        refresh.send(true)
        postListener.send((
            forced: false,
            commentInfo: (
                post: nil,
                endDocument: nil
            )))
        sort.send((sort: viewModel.activeSortMethod, useEndDoc: false))

        DispatchQueue.main.async {
            self.refreshControl.beginRefreshing()
        }
    }

    @objc func shareTap() {

    }
}

