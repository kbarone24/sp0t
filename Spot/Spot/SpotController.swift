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

final class SpotController: UIViewController {
    enum PostUpdateType: String {
        case Post
        case Like
        case Comment
        case None
    }

    typealias Input = SpotViewModel.Input
    typealias Output = SpotViewModel.Output
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>

    private let viewModel: SpotViewModel

    private var subscriptions = Set<AnyCancellable>()
    private let refresh = PassthroughSubject<Bool, Never>()
 //   private let spotListenerForced = PassthroughSubject<Bool, Never>()
    private let postListenerForced = PassthroughSubject<(Bool, (MapPost?, DocumentSnapshot?)), Never>()
    private let sort = PassthroughSubject<SpotViewModel.SortMethod, Never>()

    private var likeAction = false
    private var disablePagination: Bool {
        switch viewModel.activeSortMethod {
        case .New: return viewModel.disableRecentPagination
        case .Top: return viewModel.disableTopPagination
        }
    }

    private var emptyStateHidden = true

    weak var cameraPicker: UIImagePickerController?
    weak var galleryPicker: PHPickerViewController?

    private lazy var datasource: DataSource = {
        let dataSource = DataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .item(post: let post):
                let cell = tableView.dequeueReusableCell(withIdentifier: SpotPostCell.reuseID, for: indexPath) as? SpotPostCell
                cell?.configure(post: post)
                cell?.delegate = self
                return cell
            }
        }
        return dataSource
    }()

    private lazy var activityIndicator = UIActivityIndicatorView()
    private(set) lazy var emptyState = MyWorldEmptyState() {
        didSet {
            emptyStateHidden = emptyState.isHidden
        }
    }

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = UIScreen.main.bounds.height / 2
        tableView.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        tableView.clipsToBounds = true
        tableView.register(SpotPostCell.self, forCellReuseIdentifier: SpotPostCell.reuseID)
        tableView.register(SpotOverviewHeader.self, forHeaderFooterViewReuseIdentifier: SpotOverviewHeader.reuseID)
        return tableView
    }()

    private lazy var textFieldFooter = SpotTextFieldFooter()
    private lazy var moveCloserFooter = SpotMoveCloserFooter()

    private var isRefreshingPagination = false {
        didSet {
            DispatchQueue.main.async {
                if self.isRefreshingPagination, !self.datasource.snapshot().itemIdentifiers.isEmpty {
                    self.tableView.layoutIfNeeded()
                    let tableBottom = self.tableView.contentSize.height
                    self.activityIndicator.snp.removeConstraints()
                    self.activityIndicator.snp.makeConstraints {
                        $0.centerX.equalToSuperview()
                        $0.width.height.equalTo(30)
                        $0.top.equalTo(tableBottom + 15)
                    }
                    self.activityIndicator.startAnimating()
                }
            }
        }
    }

    enum Section: Hashable {
        case main(spot: MapSpot, sortMethod: SpotViewModel.SortMethod)
    }

    enum Item: Hashable {
        case item(post: MapPost)
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
        NotificationCenter.default.removeObserver(self)
    }


    init(viewModel: SpotViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        view.addSubview(emptyState)
        emptyState.isHidden = true
        emptyState.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        tableView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(100)
            $0.width.height.equalTo(30)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.startAnimating()

        //TODO: resize for iPhone 8
        view.addSubview(textFieldFooter)
        textFieldFooter.delegate = self
        textFieldFooter.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(113)
        }

        view.addSubview(moveCloserFooter)
        moveCloserFooter.delegate = self
        moveCloserFooter.snp.makeConstraints {
            $0.edges.equalTo(textFieldFooter)
        }

        let input = Input(
            refresh: refresh,
        //    spotListenerForced: spotListenerForced,
            postListenerForced: postListenerForced,
            sort: sort
        )

        let output = viewModel.bind(to: input)
        output.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.datasource.apply(snapshot, animatingDifferences: false)
                self?.activityIndicator.stopAnimating()
                self?.isRefreshingPagination = false
                self?.emptyState.isHidden = !(self?.viewModel.postsAreEmpty() ?? false)
            }
            .store(in: &subscriptions)


        refresh.send(true)
        postListenerForced.send((false, (nil, nil)))
        sort.send(.New)

        subscribeToPostListener()
        addFooter()
    }

    private func setUpNavBar() {
        navigationController?.setUpDarkNav(translucent: false)
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont(name: "UniversCE-Black", size: 19) as Any
        ]
        navigationItem.title = viewModel.cachedSpot.spotName
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "WhiteShareButton"), style: .plain, target: self, action: #selector(shareTap))
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
                    print("receive listener value")
                    guard let self,
                          !completion.metadata.isFromCache,
                          !completion.documentChanges.isEmpty,
                          self.viewModel.activeSortMethod == .New,
                          (!self.emptyStateHidden || !self.datasource.snapshot().itemIdentifiers.isEmpty)
                    else { return }

                    viewModel.addedPostIDs = completion.documentChanges.filter({ $0.type == .added }).map({ $0.document.documentID })
                    viewModel.removedPostIDs = completion.documentChanges.filter({ $0.type == .removed }).map({ $0.document.documentID })
                    viewModel.modifiedPostIDs = completion.documentChanges.filter({ $0.type == .modified }).map({ $0.document.documentID })

                    // block seenList and other unnecessary updates
                    let postUpdateData = getPostUpdateType(documents: completion.documents)
                    let postUpdateType = postUpdateData.0
                    print("post update type", postUpdateType)
                    switch postUpdateType {
                    case .None:
                        return
                    case .Comment:
                        if let post = postUpdateData.1 {
                            refresh.send(true)
                            postListenerForced.send((true, (post, nil)))
                            sort.send(.New)
                        } else {
                            fallthrough
                        }
                    default:
                        refresh.send(true)
                        postListenerForced.send((true, (nil, nil)))
                        sort.send(.New)
                    }
                    guard postUpdateType != .None else {
                        return
                    }

    //                spotListenerForced.send(false)
                })
            .store(in: &subscriptions)
    }

    private func addFooter() {
        if viewModel.userIsInRange() {
            textFieldFooter.isHidden = false
            moveCloserFooter.isHidden = true
        } else {
            textFieldFooter.isHidden = true
            moveCloserFooter.isHidden = false
        }
    }

    // return PostUpdateType + post for comment updates if applicable
    private func getPostUpdateType(documents: [QueryDocumentSnapshot]) -> (PostUpdateType, MapPost?) {
        if !viewModel.addedPostIDs.isEmpty || !viewModel.removedPostIDs.isEmpty {
            return (.Post, nil)
        }
        guard !likeAction else {
            return (.None, nil)
        }
        for doc in documents {
            let post = try? doc.data(as: MapPost.self)
            if let post, let cachedPost = viewModel.presentedPosts[id: post.id ?? ""] {
                if post.likers.count != cachedPost.likers.count {
                    return (.Like, nil)
                }
                if post.commentCount != cachedPost.commentCount {
                    return (.Comment, cachedPost)
                }
                if post.dislikers.count != cachedPost.dislikers.count {
                    return (.Like, nil)
                }
            }
        }
        return (.None, nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func shareTap() {

    }
}

extension SpotController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if datasource.snapshot().sectionIdentifiers.isEmpty { return UIView() }
        let section = datasource.snapshot().sectionIdentifiers[section]
        switch section {
        case .main(spot: let spot, let activeSortMethod):
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: SpotOverviewHeader.reuseID) as? SpotOverviewHeader
            header?.configure(spot: spot, sort: activeSortMethod)
            header?.sortButton.addTarget(self, action: #selector(sortTap), for: .touchUpInside)
            return header
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let snapshot = datasource.snapshot()
        if (indexPath.row >= snapshot.numberOfItems - 2) && !isRefreshingPagination, !disablePagination {
            isRefreshingPagination = true
            refresh.send(true)
            self.postListenerForced.send((false, (nil, nil)))
            sort.send(viewModel.activeSortMethod)
        }
    }

    @objc func sortTap() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "New", style: .default) { [weak self] _ in
                // sort by new
                guard let self, self.viewModel.activeSortMethod == .Top else { return }
                self.viewModel.activeSortMethod = .New
                self.refresh.send(false)

                self.refresh.send(true)
                self.postListenerForced.send((false, (nil, nil)))
                self.sort.send(.New)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Top", style: .default) { [weak self] _ in
                guard let self, self.viewModel.activeSortMethod == .New else { return }
                self.viewModel.activeSortMethod = .Top
                self.refresh.send(false)

                self.viewModel.lastRecentDocument = nil
                self.refresh.send(true)
                self.postListenerForced.send((false, (nil, nil)))
                self.sort.send(.Top)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Dismiss", style: .cancel) { _ in }
        )

        present(alert, animated: true)
    }
}

extension SpotController: PostCellDelegate {
    func likePost(post: MapPost) {
        viewModel.likePost(post: post)
        refresh.send(false)
    }

    func unlikePost(post: MapPost) {
        viewModel.unlikePost(post: post)
        refresh.send(false)
    }

    func dislikePost(post: MapPost) {
        viewModel.dislikePost(post: post)
        refresh.send(false)
    }

    func undislikePost(post: MapPost) {
        viewModel.undislikePost(post: post)
        refresh.send(false)
    }

    func viewMoreTap(parentPostID: String) {
        if let post = viewModel.presentedPosts.first(where: { $0.id == parentPostID }) {
            refresh.send(true)
            postListenerForced.send((true, (post, post.lastCommentDocument)))
            sort.send(viewModel.activeSortMethod)
        }
    }

    func replyTap(parentPostID: String, replyUsername: String) {
        openCreate(parentPostID: parentPostID, replyUsername: replyUsername, imageObject: nil, videoObject: nil)
    }
}

extension SpotController: SpotTextFieldFooterDelegate {
    func userTap() {
        print("user tap")
    }

    func textAreaTap() {
        openCreate(parentPostID: nil, replyUsername: nil, imageObject: nil, videoObject: nil)
    }

    func cameraTap() {
        addActionSheet()
    }

    func addActionSheet() {
        // add camera here, return to SpotController on cancel, push Create with selected content on confirm
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
                guard let self else { return }
                let picker = UIImagePickerController()
                picker.allowsEditing = false
                picker.mediaTypes = ["public.image", "public.movie"]
                picker.sourceType = .camera
                picker.videoMaximumDuration = 15
                picker.videoQuality = .typeHigh
                picker.delegate = self
                self.cameraPicker = picker
                self.present(picker, animated: true)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Gallery", style: .default) { [weak self] _ in
                guard let self else { return }
                var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
                config.filter = .any(of: [.images, .videos])
                config.selectionLimit = 1
                config.preferredAssetRepresentationMode = .current
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                self.galleryPicker = picker
                self.present(picker, animated: true)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Dismiss", style: .cancel) { _ in
            }
        )
        present(alert, animated: true)
    }

    func openCreate(parentPostID: String?, replyUsername: String?, imageObject: ImageObject?, videoObject: VideoObject?) {
        let vc = CreatePostController(spot: viewModel.cachedSpot, parentPostID: parentPostID, replyUsername: replyUsername, imageObject: imageObject, videoObject: videoObject)
        vc.delegate = self
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: false)
        }
    }
}

extension SpotController: SpotMoveCloserFooterDelegate {
    func refreshLocation() {
        addFooter()
    }
}

extension SpotController: CreatePostDelegate {
    func finishUpload(post: MapPost) {
        viewModel.addNewPost(post: post)
        self.refresh.send(false)
        
        if let index = viewModel.presentedPosts.firstIndex(where: { $0.id == post.id ?? "" }) {
            print("got index", index)
            DispatchQueue.main.async {
                self.tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .top, animated: false)
            }
        }
    }
}
